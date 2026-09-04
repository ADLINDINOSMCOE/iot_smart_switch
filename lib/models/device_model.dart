import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Authoritative Device Telemetry Model:
/// - deviceId: string (document ID in devices collection)
/// - lastSeen: timestamp (heartbeat signal timestamp)
/// - actualStates: map of switchId (string) to physical relay state (boolean)
@immutable
class DeviceModel {
  final String deviceId;
  final DateTime lastSeen;
  final Map<String, bool> actualStates;

  static const Duration offlineTimeout = Duration(seconds: 25);

  const DeviceModel({
    required this.deviceId,
    required this.lastSeen,
    this.actualStates = const {},
  });

  /// Evaluates online status using the authoritative 25-second timeout threshold
  bool get isOnline {
    final now = DateTime.now();
    return now.difference(lastSeen) <= offlineTimeout;
  }

  /// Verifies if a switch's desired state matches the reported physical state
  bool isSwitchSynced(String switchId, bool desiredIsOn) {
    if (!actualStates.containsKey(switchId)) {
      return false;
    }
    return actualStates[switchId] == desiredIsOn;
  }

  factory DeviceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return DeviceModel.fromMap(snapshot.id, data);
  }

  factory DeviceModel.fromMap(String deviceId, Map<String, dynamic> data) {
    DateTime parsedLastSeen;
    final rawLastSeen = data['lastSeen'];
    if (rawLastSeen is Timestamp) {
      parsedLastSeen = rawLastSeen.toDate();
    } else if (rawLastSeen is int) {
      parsedLastSeen = DateTime.fromMillisecondsSinceEpoch(rawLastSeen);
    } else if (rawLastSeen is String) {
      parsedLastSeen = DateTime.tryParse(rawLastSeen) ?? DateTime.now();
    } else {
      parsedLastSeen = DateTime.now();
    }

    final Map<String, bool> parsedStates = {};
    final rawActualStates = data['actualStates'];
    if (rawActualStates is Map) {
      rawActualStates.forEach((key, value) {
        if (key is String && value is bool) {
          parsedStates[key] = value;
        }
      });
    }

    return DeviceModel(
      deviceId: deviceId,
      lastSeen: parsedLastSeen,
      actualStates: parsedStates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastSeen': Timestamp.fromDate(lastSeen),
      'actualStates': actualStates,
    };
  }

  DeviceModel copyWith({
    String? deviceId,
    DateTime? lastSeen,
    Map<String, bool>? actualStates,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      lastSeen: lastSeen ?? this.lastSeen,
      actualStates: actualStates ?? this.actualStates,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceModel &&
        other.deviceId == deviceId &&
        other.lastSeen == lastSeen &&
        mapEquals(other.actualStates, actualStates);
  }

  @override
  int get hashCode => Object.hash(
        deviceId,
        lastSeen,
        Object.hashAll(actualStates.entries),
      );

  @override
  String toString() {
    return 'DeviceModel(deviceId: $deviceId, lastSeen: $lastSeen, '
        'actualStates: $actualStates, isOnline: $isOnline)';
  }
}
