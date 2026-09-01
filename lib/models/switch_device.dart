import 'package:cloud_firestore/cloud_firestore.dart';

enum DeviceRole {
  owner,
  editor,
  viewer,
  none;

  static DeviceRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'owner':
        return DeviceRole.owner;
      case 'editor':
      case 'control':
        return DeviceRole.editor;
      case 'viewer':
      case 'view only':
      case 'view_only':
        return DeviceRole.viewer;
      default:
        return DeviceRole.none;
    }
  }

  String toDisplayString() {
    switch (this) {
      case DeviceRole.owner:
        return 'Owner';
      case DeviceRole.editor:
        return 'Control';
      case DeviceRole.viewer:
        return 'View Only';
      case DeviceRole.none:
        return 'No Access';
    }
  }
}

class SharedUser {
  final String uid;
  final String email;
  final DeviceRole role;

  SharedUser({
    required this.uid,
    required this.email,
    required this.role,
  });

  factory SharedUser.fromMap(Map<String, dynamic> map) {
    return SharedUser(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: DeviceRole.fromString(map['role']?.toString() ?? map['permission']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role.name,
    };
  }
}

class SwitchDevice {
  final String id;
  final String name;
  final String room;
  final bool isOn;
  final String deviceId;
  final bool online;
  final String ownerId;
  final Map<String, String> sharedWith;
  final List<String> sharedWithUids;
  final List<SharedUser> sharedUsers;
  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;
  final DateTime? turnedOnAt;
  final bool timerActive;
  final DateTime? timerStartedAt;
  final int timerDurationSeconds;

  SwitchDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.isOn,
    required this.deviceId,
    required this.online,
    required this.ownerId,
    this.sharedWith = const {},
    this.sharedWithUids = const [],
    this.sharedUsers = const [],
    this.lastUpdatedBy,
    this.lastUpdatedAt,
    this.turnedOnAt,
    this.timerActive = false,
    this.timerStartedAt,
    this.timerDurationSeconds = 0,
  });

  DeviceRole getRoleForUser(String? uid) {
    if (uid == null || uid.isEmpty) return DeviceRole.none;
    if (ownerId == uid) return DeviceRole.owner;
    final sharedRole = sharedWith[uid];
    if (sharedRole != null) {
      final parsed = DeviceRole.fromString(sharedRole);
      // Shared users can never claim or inherit ownership.
      if (parsed == DeviceRole.owner) return DeviceRole.none;
      return parsed;
    }
    return DeviceRole.none;
  }

  bool isOwner(String? uid) => uid != null && uid.isNotEmpty && ownerId == uid;
  bool canControl(String? uid) {
    if (isOwner(uid)) return true;
    final role = getRoleForUser(uid);
    return role == DeviceRole.editor;
  }
  bool canShare(String? uid) => isOwner(uid);

  factory SwitchDevice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SwitchDevice.fromMap(doc.id, data);
  }

  factory SwitchDevice.fromMap(String id, Map<String, dynamic> data) {
    Map<String, String> parsedSharedWith = {};
    if (data['sharedWith'] is Map) {
      (data['sharedWith'] as Map).forEach((k, v) {
        if (k != null && v != null) {
          parsedSharedWith[k.toString()] = v.toString();
        }
      });
    }

    List<String> parsedSharedWithUids = [];
    if (data['sharedWithUids'] is List) {
      parsedSharedWithUids = (data['sharedWithUids'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (parsedSharedWith.isNotEmpty) {
      parsedSharedWithUids = parsedSharedWith.keys.toList();
    }

    List<SharedUser> parsedSharedUsers = [];
    if (data['sharedUsers'] is List) {
      for (final item in data['sharedUsers']) {
        if (item is Map) {
          parsedSharedUsers.add(
            SharedUser.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return SwitchDevice(
      id: id,
      name: data['name']?.toString() ?? 'Switch',
      room: data['room']?.toString() ?? 'Default Room',
      isOn: data['isOn'] == true,
      deviceId: data['deviceId']?.toString() ?? id,
      online: data['online'] ?? true,
      ownerId: data['ownerId']?.toString() ?? '',
      sharedWith: parsedSharedWith,
      sharedWithUids: parsedSharedWithUids,
      sharedUsers: parsedSharedUsers,
      lastUpdatedBy: data['lastUpdatedBy']?.toString(),
      lastUpdatedAt: parseDate(data['lastUpdatedAt']),
      turnedOnAt: parseDate(data['turnedOnAt']),
      timerActive: data['timerActive'] == true,
      timerStartedAt: parseDate(data['timerStartedAt']),
      timerDurationSeconds: (data['timerDurationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'room': room,
      'isOn': isOn,
      'deviceId': deviceId,
      'online': online,
      'ownerId': ownerId,
      'sharedWith': sharedWith,
      'sharedWithUids': sharedWithUids,
      'sharedUsers': sharedUsers.map((u) => u.toMap()).toList(),
      'lastUpdatedBy': lastUpdatedBy,
      'lastUpdatedAt': lastUpdatedAt != null ? Timestamp.fromDate(lastUpdatedAt!) : null,
      'turnedOnAt': turnedOnAt != null ? Timestamp.fromDate(turnedOnAt!) : null,
      'timerActive': timerActive,
      'timerStartedAt': timerStartedAt != null ? Timestamp.fromDate(timerStartedAt!) : null,
      'timerDurationSeconds': timerDurationSeconds,
    };
  }
}
