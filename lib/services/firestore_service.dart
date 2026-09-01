import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/switch_device.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUid => _auth.currentUser?.uid;

  // =========================================================
  // REACTIVE STREAMS: GET USER DEVICES (OWNED + SHARED)
  // =========================================================
  Stream<List<SwitchDevice>> getDevicesStream() => streamUserDevices();

  /// Direct reactive stream combining owned and shared devices for current user
  Stream<List<SwitchDevice>> streamUserDevices() {
    final uid = _currentUid;
    if (uid == null) {
      return Stream.value([]);
    }

    // We can use a StreamGroup or async generator to merge both queries
    final ownedStream = _firestore
        .collection('switches')
        .where('ownerId', isEqualTo: uid)
        .snapshots();

    final sharedStream = _firestore
        .collection('switches')
        .where('sharedWithUids', arrayContains: uid)
        .snapshots();

    final controller = StreamController<List<SwitchDevice>>.broadcast();
    List<SwitchDevice> ownedDevices = [];
    List<SwitchDevice> sharedDevices = [];

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitMerged() {
      if (controller.isClosed) return;
      final Map<String, SwitchDevice> deviceMap = {};
      for (final d in ownedDevices) {
        deviceMap[d.id] = d;
      }
      for (final d in sharedDevices) {
        deviceMap[d.id] = d;
      }
      final list = deviceMap.values.toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      controller.add(list);
    }

    controller.onListen = () {
      sub1 = ownedStream.listen(
        (snapshot) {
          ownedDevices = snapshot.docs.map((doc) => SwitchDevice.fromFirestore(doc)).toList();
          emitMerged();
        },
        onError: (e) {
          debugPrint('Error streaming owned devices: $e');
          if (!controller.isClosed) controller.addError(e);
        },
      );

      sub2 = sharedStream.listen(
        (snapshot) {
          sharedDevices = snapshot.docs.map((doc) => SwitchDevice.fromFirestore(doc)).toList();
          emitMerged();
        },
        onError: (e) {
          debugPrint('Error streaming shared devices: $e');
          if (!controller.isClosed) controller.addError(e);
        },
      );
    };

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  // =========================================================
  // BACKWARDS-COMPATIBLE STREAM ADAPTER FOR HOME SCREEN
  // Returns raw map list compatible with existing screens
  // =========================================================
  Stream<List<Map<String, dynamic>>> getSwitchesAsMaps() {
    return streamUserDevices().map((devices) {
      return devices.map((d) {
        return {
          'id': d.id,
          'name': d.name,
          'room': d.room,
          'isOn': d.isOn,
          'deviceId': d.deviceId,
          'online': d.online,
          'ownerId': d.ownerId,
          'role': d.getRoleForUser(_currentUid).name,
          'canControl': d.canControl(_currentUid),
          'isOwner': d.isOwner(_currentUid),
          'sharedWith': d.sharedWith,
          'sharedUsers': d.sharedUsers.map((u) => u.toMap()).toList(),
          'timerActive': d.timerActive,
          'timerStartedAt': d.timerStartedAt,
        };
      }).toList();
    });
  }

  static bool isValidDeviceId(String? id) {
    if (id == null) return false;
    final clean = id.trim();
    if (clean.length < 3 || clean.length > 50) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(clean);
  }

  // =========================================================
  // ADD NEW SWITCH DEVICE (OWNER = CURRENT USER)
  // =========================================================
  Future<String> addDevice({
    required String name,
    required String room,
    String? deviceId,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be logged in to create a device.');
    }

    final trimmedName = name.trim();
    final trimmedRoom = room.trim().isEmpty ? 'Main Room' : room.trim();

    if (trimmedName.isEmpty || trimmedName.length > 60) {
      throw Exception('Device name must be between 1 and 60 characters.');
    }
    if (trimmedRoom.length > 60) {
      throw Exception('Room name must be under 60 characters.');
    }

    final docRef = deviceId != null && deviceId.trim().isNotEmpty
        ? _firestore.collection('switches').doc(deviceId.trim())
        : _firestore.collection('switches').doc();
    final finalDeviceId = docRef.id;

    if (!isValidDeviceId(finalDeviceId)) {
      throw Exception('Invalid Device ID format. Use 3-50 alphanumeric characters, hyphens, or underscores.');
    }

    final deviceData = {
      'name': trimmedName,
      'room': trimmedRoom,
      'isOn': false,
      'deviceId': finalDeviceId,
      'online': true,
      'ownerId': uid,
      'sharedWith': <String, String>{},
      'sharedWithUids': <String>[],
      'sharedUsers': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': uid,
      'timerActive': false,
      'timerDurationSeconds': 0,
    };

    await docRef.set(deviceData);
    return finalDeviceId;
  }

  // =========================================================
  // UPDATE SWITCH + AUTOMATIC ON TIME TRACKING
  // =========================================================
  Future<void> updateSwitch(
    String switchId,
    bool value,
  ) async {
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('Unauthenticated: User is not signed in.');
    }

    final switchRef = _firestore.collection('switches').doc(switchId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(switchRef);

        if (!snapshot.exists) {
          throw Exception('Switch not found');
        }

        final data = snapshot.data() ?? {};
        final switchDevice = SwitchDevice.fromMap(snapshot.id, data);

        // Security check: Verify user is owner or editor
        if (!switchDevice.canControl(uid)) {
          throw Exception('Permission Denied: You do not have permission to control this device.');
        }

        final bool currentState = data['isOn'] == true;

        // Do nothing if already in requested state
        if (currentState == value) {
          return;
        }

        final now = Timestamp.now();
        final actionStr = value ? 'TURN_ON' : 'TURN_OFF';

        if (value == true) {
          // SWITCH TURNED ON
          transaction.update(
            switchRef,
            {
              'isOn': true,
              'turnedOnAt': now,
              'timerStartedAt': now,
              'lastUpdatedAt': now,
              'lastUpdatedBy': uid,
            },
          );
        } else {
          // SWITCH TURNED OFF
          final startedAt = data['timerStartedAt'] ?? data['turnedOnAt'];

          transaction.update(
            switchRef,
            {
              'isOn': false,
              'turnedOnAt': FieldValue.delete(),
              'timerStartedAt': FieldValue.delete(),
              'lastUpdatedAt': now,
              'lastUpdatedBy': uid,
            },
          );

          // Save duration in timerHistory subcollection
          int durationSeconds = 0;
          if (startedAt is Timestamp) {
            final startedDate = startedAt.toDate();
            final stoppedDate = now.toDate();
            durationSeconds = stoppedDate.difference(startedDate).inSeconds;
            if (durationSeconds < 0) durationSeconds = 0;
          }

          final historyRef = switchRef.collection('timerHistory').doc();
          final historyData = {
            'startedAt': startedAt is Timestamp ? startedAt : now,
            'stoppedAt': now,
            'durationSeconds': durationSeconds,
            'status': 'completed',
            'startedBy': uid,
            'mode': 'manualUsage',
          };
          transaction.set(historyRef, historyData);
        }

        // Log command execution
        final commandRef = switchRef.collection('commands').doc();
        transaction.set(commandRef, {
          'action': actionStr,
          'targetState': value,
          'requestedBy': uid,
          'deviceId': switchId,
          'timestamp': now,
          'status': 'EXECUTED',
        });

        // Log device audit event
        final logRef = switchRef.collection('deviceLogs').doc();
        transaction.set(logRef, {
          'event': actionStr,
          'userId': uid,
          'deviceId': switchId,
          'timestamp': now,
        });
      });
    } catch (e) {
      debugPrint('Error updating switch: $e');
      rethrow;
    }
  }

  // =========================================================
  // SHARE DEVICE WITH USER BY EMAIL
  // =========================================================
  Future<void> shareDeviceWithEmail({
    required String deviceId,
    required String targetEmail,
    required String role, // 'editor' or 'viewer'
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final cleanEmail = targetEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) throw Exception('Email cannot be empty');

    // 1. Look up target user by email in users collection
    final targetUser = await AuthService().findUserByEmail(cleanEmail);
    if (targetUser == null) {
      throw Exception('No registered user found with email $cleanEmail. The user must create an account first.');
    }

    final targetUid = targetUser['uid'] as String;

    if (targetUid == uid) {
      throw Exception('You are already the owner of this device.');
    }

    final switchRef = _firestore.collection('switches').doc(deviceId);
    final snapshot = await switchRef.get();
    if (!snapshot.exists) throw Exception('Device not found');

    final data = snapshot.data() ?? {};
    final device = SwitchDevice.fromMap(snapshot.id, data);

    if (!device.isOwner(uid)) {
      throw Exception('Permission Denied: Only the device owner can share devices.');
    }

    // Update shared maps and lists
    final updatedSharedWith = Map<String, String>.from(device.sharedWith);
    updatedSharedWith[targetUid] = role;

    final updatedSharedWithUids = Set<String>.from(device.sharedWithUids)..add(targetUid);

    final List<Map<String, dynamic>> updatedSharedUsers = device.sharedUsers
        .where((u) => u.uid != targetUid)
        .map((u) => u.toMap())
        .toList();

    updatedSharedUsers.add({
      'uid': targetUid,
      'email': cleanEmail,
      'role': role,
    });

    await switchRef.update({
      'sharedWith': updatedSharedWith,
      'sharedWithUids': updatedSharedWithUids.toList(),
      'sharedUsers': updatedSharedUsers,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // REMOVE SHARED USER ACCESS
  // =========================================================
  Future<void> removeSharedUser({
    required String deviceId,
    required String targetUid,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final switchRef = _firestore.collection('switches').doc(deviceId);
    final snapshot = await switchRef.get();
    if (!snapshot.exists) throw Exception('Device not found');

    final data = snapshot.data() ?? {};
    final device = SwitchDevice.fromMap(snapshot.id, data);

    if (!device.isOwner(uid)) {
      throw Exception('Permission Denied: Only the device owner can modify sharing.');
    }

    final updatedSharedWith = Map<String, String>.from(device.sharedWith)..remove(targetUid);
    final updatedSharedWithUids = Set<String>.from(device.sharedWithUids)..remove(targetUid);
    final updatedSharedUsers = device.sharedUsers
        .where((u) => u.uid != targetUid)
        .map((u) => u.toMap())
        .toList();

    await switchRef.update({
      'sharedWith': updatedSharedWith,
      'sharedWithUids': updatedSharedWithUids.toList(),
      'sharedUsers': updatedSharedUsers,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // DELETE DEVICE (OWNER ONLY)
  // =========================================================
  Future<void> deleteDevice(String deviceId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    final switchRef = _firestore.collection('switches').doc(deviceId);
    final snapshot = await switchRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? {};
    final device = SwitchDevice.fromMap(snapshot.id, data);

    if (!device.isOwner(uid)) {
      throw Exception('Permission Denied: Only the owner can delete this device.');
    }

    await switchRef.delete();
  }
}