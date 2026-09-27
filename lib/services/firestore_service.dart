import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/switch_device.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirestoreService _instance =
  FirestoreService._internal();

  factory FirestoreService() => _instance;

  FirestoreService._internal();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String? get _currentUid =>
      _auth.currentUser?.uid;

  // =========================================================
  // REACTIVE STREAMS: GET USER DEVICES
  // OWNED + SHARED
  // =========================================================

  Stream<List<SwitchDevice>> getDevicesStream() {
    return streamUserDevices();
  }

  Stream<List<SwitchDevice>> streamUserDevices() {
    final uid = _currentUid;

    if (uid == null) {
      return Stream.value([]);
    }

    final ownedStream = _firestore
        .collection('switches')
        .where(
      'ownerId',
      isEqualTo: uid,
    )
        .snapshots();

    final sharedStream = _firestore
        .collection('switches')
        .where(
      'sharedWithUids',
      arrayContains: uid,
    )
        .snapshots();

    final controller =
    StreamController<List<SwitchDevice>>.broadcast();

    List<SwitchDevice> ownedDevices = [];
    List<SwitchDevice> sharedDevices = [];

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitMerged() {
      if (controller.isClosed) {
        return;
      }

      final Map<String, SwitchDevice> deviceMap = {};

      for (final device in ownedDevices) {
        deviceMap[device.id] = device;
      }

      for (final device in sharedDevices) {
        deviceMap[device.id] = device;
      }

      final list = deviceMap.values.toList();

      list.sort(
            (a, b) => a.name.compareTo(b.name),
      );

      controller.add(list);
    }

    controller.onListen = () {
      sub1 = ownedStream.listen(
            (snapshot) {
          ownedDevices = snapshot.docs
              .map(
                (doc) =>
                SwitchDevice.fromFirestore(doc),
          )
              .toList();

          emitMerged();
        },
        onError: (e) {
          debugPrint(
            'Error streaming owned devices: $e',
          );

          if (!controller.isClosed) {
            controller.addError(e);
          }
        },
      );

      sub2 = sharedStream.listen(
            (snapshot) {
          sharedDevices = snapshot.docs
              .map(
                (doc) =>
                SwitchDevice.fromFirestore(doc),
          )
              .toList();

          emitMerged();
        },
        onError: (e) {
          debugPrint(
            'Error streaming shared devices: $e',
          );

          if (!controller.isClosed) {
            controller.addError(e);
          }
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
  // BACKWARDS COMPATIBLE STREAM ADAPTER
  // =========================================================

  Stream<List<Map<String, dynamic>>>
  getSwitchesAsMaps() {
    return streamUserDevices().map(
          (devices) {
        return devices.map(
              (device) {
            return {
              'id': device.id,
              'name': device.name,
              'room': device.room,
              'isOn': device.isOn,
              'deviceId': device.deviceId,
              'online': device.online,
              'ownerId': device.ownerId,
              'role': device
                  .getRoleForUser(_currentUid)
                  .name,
              'canControl':
              device.canControl(_currentUid),
              'isOwner':
              device.isOwner(_currentUid),
              'sharedWith':
              device.sharedWith,
              'sharedUsers': device.sharedUsers
                  .map(
                    (user) => user.toMap(),
              )
                  .toList(),
              'timerActive':
              device.timerActive,
              'timerStartedAt':
              device.timerStartedAt,
            };
          },
        ).toList();
      },
    );
  }

  // =========================================================
  // VALIDATE DEVICE ID
  // =========================================================

  static bool isValidDeviceId(String? id) {
    if (id == null) {
      return false;
    }

    final clean = id.trim();

    if (clean.length < 3 ||
        clean.length > 50) {
      return false;
    }

    return RegExp(
      r'^[a-zA-Z0-9_-]+$',
    ).hasMatch(clean);
  }

  // =========================================================
  // ADD NEW SWITCH DEVICE
  // =========================================================

  Future<String> addDevice({
    required String name,
    required String room,
    String? deviceId,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'User must be logged in to create a device.',
      );
    }

    final trimmedName = name.trim();

    final trimmedRoom =
    room.trim().isEmpty
        ? 'Main Room'
        : room.trim();

    if (trimmedName.isEmpty ||
        trimmedName.length > 60) {
      throw Exception(
        'Device name must be between 1 and 60 characters.',
      );
    }

    if (trimmedRoom.length > 60) {
      throw Exception(
        'Room name must be under 60 characters.',
      );
    }

    final docRef =
    deviceId != null &&
        deviceId.trim().isNotEmpty
        ? _firestore
        .collection('switches')
        .doc(deviceId.trim())
        : _firestore
        .collection('switches')
        .doc();

    final finalDeviceId = docRef.id;

    if (!isValidDeviceId(finalDeviceId)) {
      throw Exception(
        'Invalid Device ID format. Use 3-50 alphanumeric characters, hyphens, or underscores.',
      );
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
      'sharedUsers':
      <Map<String, dynamic>>[],
      'createdAt':
      FieldValue.serverTimestamp(),
      'lastUpdatedAt':
      FieldValue.serverTimestamp(),
      'lastUpdatedBy': uid,
      'timerActive': false,
      'timerDurationSeconds': 0,
    };

    await docRef.set(deviceData);

    return finalDeviceId;
  }

  // =========================================================
  // UPDATE SWITCH
  //
  // ON  -> START TIMER + TIMER HISTORY
  // OFF -> STOP TIMER + CALCULATE RUNTIME + ENERGY
  // =========================================================

  Future<void> updateSwitch(
      String switchId,
      bool value,
      ) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'Unauthenticated: User is not signed in.',
      );
    }

    final switchRef =
    _firestore.collection('switches').doc(
      switchId,
    );

    try {
      await _firestore.runTransaction(
            (transaction) async {
          final snapshot =
          await transaction.get(
            switchRef,
          );

          if (!snapshot.exists) {
            throw Exception(
              'Switch not found',
            );
          }

          final data =
              snapshot.data() ?? {};

          final switchDevice =
          SwitchDevice.fromMap(
            snapshot.id,
            data,
          );

          // ---------------------------------------------------
          // PERMISSION
          // ---------------------------------------------------

          if (!switchDevice.canControl(uid)) {
            throw Exception(
              'Permission Denied: You do not have permission to control this device.',
            );
          }

          final bool currentState =
              data['isOn'] == true;

          // Already requested state
          if (currentState == value) {
            return;
          }

          final now = Timestamp.now();

          final actionStr =
          value
              ? 'TURN_ON'
              : 'TURN_OFF';

          final timerWasActive =
              data['timerActive'] == true;

          // ---------------------------------------------------
          // COMMAND ID
          // ---------------------------------------------------

          final commandId =
              '${switchId}_${now.millisecondsSinceEpoch}_$uid';

          final switchUpdate =
          <String, dynamic>{
            'isOn': value,
            'lastUpdatedAt': now,
            'lastUpdatedBy': uid,
            'currentCommandId':
            commandId,
          };

          // ===================================================
          // SWITCH ON
          // ===================================================

          if (value) {
            switchUpdate[
            'turnedOnAt'] = now;

            final historyRef =
            switchRef
                .collection(
              'timerHistory',
            )
                .doc();

            transaction.set(
              historyRef,
              {
                'action':
                'SET_TIMER',
                'deviceId':
                switchId,
                'startedAt':
                now,
                'startTime':
                now,
                'stoppedAt':
                null,
                'endTime':
                null,
                'durationSeconds':
                0,
                'status':
                'active',
                'mode':
                'countUp',
                'startedBy':
                uid,
              },
            );

            switchUpdate[
            'timerActive'] = true;

            switchUpdate[
            'timerStartedAt'] =
                now;

            switchUpdate[
            'timerDurationSeconds'] =
            0;

            switchUpdate[
            'activeTimerHistoryId'] =
                historyRef.id;
          }

          // ===================================================
          // SWITCH OFF
          // ===================================================

          else {
            final turnedOnAt =
            data['turnedOnAt'];

            // -------------------------------------------------
            // CALCULATE TOTAL RUNTIME
            // -------------------------------------------------

            if (turnedOnAt is Timestamp) {
              int runtimeSeconds = now
                  .toDate()
                  .difference(
                turnedOnAt.toDate(),
              )
                  .inSeconds;

              if (runtimeSeconds < 0) {
                runtimeSeconds = 0;
              }

              if (runtimeSeconds > 0) {
                final currentTotalRuntime =
                    (data[
                    'totalRuntimeSeconds']
                    as num?)
                        ?.toInt() ??
                        0;

                final newTotalRuntime =
                    currentTotalRuntime +
                        runtimeSeconds;

                // -------------------------------------------------
                // 60W ESTIMATED ENERGY
                // -------------------------------------------------

                final currentEnergy =
                    (data[
                    'energyConsumptionKwh']
                    as num?)
                        ?.toDouble() ??
                        0.0;

                final energyKwh =
                    (runtimeSeconds * 60) /
                        3600000;

                final newEnergy =
                    currentEnergy +
                        energyKwh;

                switchUpdate[
                'totalRuntimeSeconds'] =
                    newTotalRuntime;

                switchUpdate[
                'energyConsumptionKwh'] =
                    newEnergy;
              }
            }

            switchUpdate[
            'turnedOnAt'] =
                FieldValue.delete();

            // -------------------------------------------------
            // STOP TIMER
            // -------------------------------------------------

            if (timerWasActive) {
              int durationSeconds = 0;

              final startedAt =
              data['timerStartedAt'];

              if (startedAt is Timestamp) {
                durationSeconds = now
                    .toDate()
                    .difference(
                  startedAt.toDate(),
                )
                    .inSeconds;

                if (durationSeconds < 0) {
                  durationSeconds = 0;
                }
              }

              switchUpdate[
              'timerActive'] = false;

              switchUpdate[
              'timerStartedAt'] =
                  FieldValue.delete();

              switchUpdate[
              'timerDurationSeconds'] =
                  durationSeconds;

              switchUpdate[
              'activeTimerHistoryId'] =
                  FieldValue.delete();

              final historyId =
              data[
              'activeTimerHistoryId'];

              if (historyId != null &&
                  historyId
                      .toString()
                      .isNotEmpty) {
                final historyRef =
                switchRef
                    .collection(
                  'timerHistory',
                )
                    .doc(
                  historyId
                      .toString(),
                );

                transaction.update(
                  historyRef,
                  {
                    'stoppedAt':
                    now,
                    'endTime':
                    now,
                    'durationSeconds':
                    durationSeconds,
                    'status':
                    'completed',
                  },
                );
              } else {
                _writeTimerHistoryInTransaction(
                  transaction:
                  transaction,
                  switchRef:
                  switchRef,
                  data: data,
                  uid: uid,
                  switchId:
                  switchId,
                  now: now,
                  status:
                  'completed',
                  action:
                  'CANCEL_TIMER',
                  durationSeconds:
                  durationSeconds,
                );
              }
            }
          }

          // ===================================================
          // UPDATE SWITCH
          // ===================================================

          transaction.update(
            switchRef,
            switchUpdate,
          );

          // ===================================================
          // COMMAND LOG
          // ===================================================

          _writeCommandInTransaction(
            transaction:
            transaction,
            switchRef:
            switchRef,
            action:
            actionStr,
            targetState:
            value,
            uid:
            uid,
            deviceId:
            switchId,
            now:
            now,
            commandId:
            commandId,
          );

          // ===================================================
          // DEVICE LOG
          // ===================================================

          _writeDeviceLogInTransaction(
            transaction:
            transaction,
            switchRef:
            switchRef,
            event:
            actionStr,
            uid:
            uid,
            deviceId:
            switchId,
            now:
            now,
            details: value
                ? 'relay_on_timer_started'
                : (timerWasActive
                ? 'relay_off_timer_completed'
                : 'relay_state'),
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Error updating switch: $e',
      );

      rethrow;
    }
  }

  // =========================================================
  // SHARE DEVICE
  // =========================================================

  Future<void> shareDeviceWithEmail({
    required String deviceId,
    required String targetEmail,
    required String role,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'User not authenticated',
      );
    }

    final cleanEmail =
    targetEmail.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw Exception(
        'Email cannot be empty',
      );
    }

    final targetUser =
    await AuthService()
        .findUserByEmail(
      cleanEmail,
    );

    if (targetUser == null) {
      throw Exception(
        'No registered user found with email $cleanEmail. The user must create an account first.',
      );
    }

    final targetUid =
    targetUser['uid'] as String;

    if (targetUid == uid) {
      throw Exception(
        'You are already the owner of this device.',
      );
    }

    final switchRef =
    _firestore
        .collection('switches')
        .doc(deviceId);

    final snapshot =
    await switchRef.get();

    if (!snapshot.exists) {
      throw Exception(
        'Device not found',
      );
    }

    final data =
        snapshot.data() ?? {};

    final device =
    SwitchDevice.fromMap(
      snapshot.id,
      data,
    );

    if (!device.isOwner(uid)) {
      throw Exception(
        'Permission Denied: Only the device owner can share devices.',
      );
    }

    final updatedSharedWith =
    Map<String, String>.from(
      device.sharedWith,
    );

    updatedSharedWith[targetUid] =
        role;

    final updatedSharedWithUids =
    Set<String>.from(
      device.sharedWithUids,
    )..add(targetUid);

    final List<Map<String, dynamic>>
    updatedSharedUsers =
    device.sharedUsers
        .where(
          (u) => u.uid != targetUid,
    )
        .map(
          (u) => u.toMap(),
    )
        .toList();

    updatedSharedUsers.add({
      'uid': targetUid,
      'email': cleanEmail,
      'role': role,
    });

    await switchRef.update({
      'sharedWith':
      updatedSharedWith,
      'sharedWithUids':
      updatedSharedWithUids.toList(),
      'sharedUsers':
      updatedSharedUsers,
      'lastUpdatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // REMOVE SHARED USER
  // =========================================================

  Future<void> removeSharedUser({
    required String deviceId,
    required String targetUid,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'User not authenticated',
      );
    }

    final switchRef =
    _firestore
        .collection('switches')
        .doc(deviceId);

    final snapshot =
    await switchRef.get();

    if (!snapshot.exists) {
      throw Exception(
        'Device not found',
      );
    }

    final data =
        snapshot.data() ?? {};

    final device =
    SwitchDevice.fromMap(
      snapshot.id,
      data,
    );

    if (!device.isOwner(uid)) {
      throw Exception(
        'Permission Denied: Only the device owner can modify sharing.',
      );
    }

    final updatedSharedWith =
    Map<String, String>.from(
      device.sharedWith,
    )..remove(targetUid);

    final updatedSharedWithUids =
    Set<String>.from(
      device.sharedWithUids,
    )..remove(targetUid);

    final updatedSharedUsers =
    device.sharedUsers
        .where(
          (u) => u.uid != targetUid,
    )
        .map(
          (u) => u.toMap(),
    )
        .toList();

    await switchRef.update({
      'sharedWith':
      updatedSharedWith,
      'sharedWithUids':
      updatedSharedWithUids.toList(),
      'sharedUsers':
      updatedSharedUsers,
      'lastUpdatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // DELETE DEVICE
  // OWNER ONLY
  // =========================================================

  Future<void> deleteDevice(
      String switchId,
      ) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'Unauthenticated: User is not signed in.',
      );
    }

    final switchRef =
    _firestore
        .collection('switches')
        .doc(switchId);

    final snapshot =
    await switchRef.get();

    if (!snapshot.exists) {
      throw Exception(
        'Switch not found.',
      );
    }

    final data =
    snapshot.data();

    if (data == null) {
      throw Exception(
        'Switch data not found.',
      );
    }

    final ownerId =
    data['ownerId']?.toString();

    if (ownerId != uid) {
      throw Exception(
        'Only the owner can delete this switch.',
      );
    }

    await switchRef.delete();
  }

  // =========================================================
  // START TIMER
  // =========================================================

  Future<void> startTimer(
      String deviceId,
      ) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'Unauthenticated: User is not signed in.',
      );
    }

    final switchRef =
    _firestore
        .collection('switches')
        .doc(deviceId);

    await _firestore.runTransaction(
          (transaction) async {
        final snapshot =
        await transaction.get(
          switchRef,
        );

        if (!snapshot.exists) {
          throw Exception(
            'Switch not found',
          );
        }

        final data =
            snapshot.data() ?? {};

        final switchDevice =
        SwitchDevice.fromMap(
          snapshot.id,
          data,
        );

        if (!switchDevice.canControl(
          uid,
        )) {
          throw Exception(
            'Permission Denied: You do not have permission to control this device.',
          );
        }

        if (data['timerActive'] ==
            true) {
          throw Exception(
            'Timer is already running',
          );
        }

        final now =
        Timestamp.now();

        final historyRef =
        switchRef
            .collection(
          'timerHistory',
        )
            .doc();

        transaction.set(
          historyRef,
          {
            'action':
            'SET_TIMER',
            'deviceId':
            deviceId,
            'startedAt':
            now,
            'startTime':
            now,
            'stoppedAt':
            null,
            'endTime':
            null,
            'durationSeconds':
            0,
            'status':
            'active',
            'mode':
            'countUp',
            'startedBy':
            uid,
          },
        );

        transaction.update(
          switchRef,
          {
            'timerActive':
            true,
            'timerStartedAt':
            now,
            'timerDurationSeconds':
            0,
            'activeTimerHistoryId':
            historyRef.id,
            'lastUpdatedBy':
            uid,
            'lastUpdatedAt':
            now,
          },
        );

        _writeCommandInTransaction(
          transaction:
          transaction,
          switchRef:
          switchRef,
          action:
          'SET_TIMER',
          targetState:
          data['isOn'] == true,
          uid:
          uid,
          deviceId:
          deviceId,
          now:
          now,
          commandId:
          null,
        );

        _writeDeviceLogInTransaction(
          transaction:
          transaction,
          switchRef:
          switchRef,
          event:
          'SET_TIMER',
          uid:
          uid,
          deviceId:
          deviceId,
          now:
          now,
          details:
          'timer_started',
        );
      },
    );
  }

  // =========================================================
  // STOP TIMER
  // =========================================================

  Future<void> stopTimer(
      String deviceId,
      ) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'Unauthenticated: User is not signed in.',
      );
    }

    final switchRef =
    _firestore
        .collection('switches')
        .doc(deviceId);

    await _firestore.runTransaction(
          (transaction) async {
        final snapshot =
        await transaction.get(
          switchRef,
        );

        if (!snapshot.exists) {
          throw Exception(
            'Switch not found',
          );
        }

        final data =
            snapshot.data() ?? {};

        final switchDevice =
        SwitchDevice.fromMap(
          snapshot.id,
          data,
        );

        if (!switchDevice.canControl(
          uid,
        )) {
          throw Exception(
            'Permission Denied: You do not have permission to control this device.',
          );
        }

        if (data['timerActive'] !=
            true) {
          return;
        }

        final now =
        Timestamp.now();

        int durationSeconds = 0;

        final startedAt =
        data['timerStartedAt'];

        if (startedAt is Timestamp) {
          durationSeconds = now
              .toDate()
              .difference(
            startedAt.toDate(),
          )
              .inSeconds;

          if (durationSeconds < 0) {
            durationSeconds = 0;
          }
        }

        transaction.update(
          switchRef,
          {
            'timerActive':
            false,
            'timerStartedAt':
            FieldValue.delete(),
            'timerDurationSeconds':
            durationSeconds,
            'activeTimerHistoryId':
            FieldValue.delete(),
            'lastUpdatedBy':
            uid,
            'lastUpdatedAt':
            now,
          },
        );

        _writeTimerHistoryInTransaction(
          transaction:
          transaction,
          switchRef:
          switchRef,
          data:
          data,
          uid:
          uid,
          switchId:
          deviceId,
          now:
          now,
          status:
          'completed',
          action:
          'CANCEL_TIMER',
          durationSeconds:
          durationSeconds,
        );

        _writeCommandInTransaction(
          transaction:
          transaction,
          switchRef:
          switchRef,
          action:
          'CANCEL_TIMER',
          targetState:
          data['isOn'] == true,
          uid:
          uid,
          deviceId:
          deviceId,
          now:
          now,
          commandId:
          null,
        );

        _writeDeviceLogInTransaction(
          transaction:
          transaction,
          switchRef:
          switchRef,
          event:
          'CANCEL_TIMER',
          uid:
          uid,
          deviceId:
          deviceId,
          now:
          now,
          details:
          'timer_completed',
        );
      },
    );
  }

  // =========================================================
  // TIMER HISTORY HELPER
  // =========================================================

  void _writeTimerHistoryInTransaction({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>>
    switchRef,
    required Map<String, dynamic> data,
    required String uid,
    required String switchId,
    required Timestamp now,
    required String status,
    required String action,
    int? durationSeconds,
  }) {
    final startedAt =
    data['timerStartedAt'];

    int duration =
        durationSeconds ?? 0;

    if (durationSeconds == null &&
        startedAt is Timestamp) {
      duration = now
          .toDate()
          .difference(
        startedAt.toDate(),
      )
          .inSeconds;

      if (duration < 0) {
        duration = 0;
      }
    }

    final historyId =
    data['activeTimerHistoryId']
        ?.toString();

    final historyData =
    <String, dynamic>{
      'action': action,
      'deviceId': switchId,
      'stoppedAt': now,
      'endTime': now,
      'durationSeconds':
      duration,
      'status': status,
      'startedBy': uid,
    };

    if (historyId != null &&
        historyId.isNotEmpty) {
      transaction.set(
        switchRef
            .collection('timerHistory')
            .doc(historyId),
        historyData,
        SetOptions(
          merge: true,
        ),
      );
    } else {
      historyData[
      'startedAt'] =
      startedAt is Timestamp
          ? startedAt
          : now;

      historyData[
      'startTime'] =
      startedAt is Timestamp
          ? startedAt
          : now;

      historyData['mode'] =
      'countUp';

      transaction.set(
        switchRef
            .collection('timerHistory')
            .doc(),
        historyData,
      );
    }
  }

  // =========================================================
  // COMMAND LOG
  // =========================================================

  void _writeCommandInTransaction({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>>
    switchRef,
    required String action,
    required bool targetState,
    required String uid,
    required String deviceId,
    required Timestamp now,
    String? commandId,
  }) {
    final commandData =
    <String, dynamic>{
      'action': action,
      'targetState':
      targetState,
      'requestedBy': uid,
      'deviceId': deviceId,
      'timestamp': now,
      'status': 'EXECUTED',
    };

    if (commandId != null) {
      commandData[
      'commandId'] = commandId;
    }

    transaction.set(
      switchRef
          .collection('commands')
          .doc(),
      commandData,
    );
  }

  // =========================================================
  // DEVICE LOG
  // =========================================================

  void _writeDeviceLogInTransaction({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>>
    switchRef,
    required String event,
    required String uid,
    required String deviceId,
    required Timestamp now,
    String? details,
  }) {
    transaction.set(
      switchRef
          .collection('deviceLogs')
          .doc(),
      {
        'event': event,
        'userId': uid,
        'deviceId': deviceId,
        'timestamp': now,
        if (details != null)
          'details': details,
      },
    );
  }

  // =========================================================
  // POWER STATISTICS
  //
  // Returns:
  //   runtimeSeconds
  //   energyKwh
  //
  // The calculation is based on timerHistory.
  //
  // Existing project assumption:
  // Switch load = 60W
  //
  // Energy:
  // runtime hours × 0.06 kW
  // =========================================================

  Future<Map<String, dynamic>> getPowerStatistics({
    required String deviceId,
    DateTime? date,
  }) async {
    final selectedDate = date ?? DateTime.now();

    final dayStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final dayEnd = dayStart.add(
      const Duration(days: 1),
    );

    final snapshot = await _firestore
        .collection('switches')
        .doc(deviceId)
        .collection('timerHistory')
        .orderBy('startedAt')
        .get();

    int totalRuntimeSeconds = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final startedAtValue =
          data['startedAt'] ?? data['startTime'];

      if (startedAtValue is! Timestamp) {
        continue;
      }

      final startedAt = startedAtValue.toDate();

      final stoppedAtValue =
          data['stoppedAt'] ?? data['endTime'];

      DateTime endedAt;

      if (stoppedAtValue is Timestamp) {
        endedAt = stoppedAtValue.toDate();
      } else if (data['status'] == 'active') {
        endedAt = DateTime.now();
      } else {
        continue;
      }

      final overlapStart =
      startedAt.isAfter(dayStart)
          ? startedAt
          : dayStart;

      final overlapEnd =
      endedAt.isBefore(dayEnd)
          ? endedAt
          : dayEnd;

      if (overlapEnd.isAfter(overlapStart)) {
        totalRuntimeSeconds +=
            overlapEnd.difference(overlapStart).inSeconds;
      }
    }

    // Existing estimated power = 60W
    final energyKwh =
        (totalRuntimeSeconds * 60) / 3600000;

    return {
      'runtimeSeconds': totalRuntimeSeconds,
      'energyKwh': energyKwh,
    };
  }
}