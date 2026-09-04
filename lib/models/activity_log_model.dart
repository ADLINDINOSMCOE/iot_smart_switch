import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Activity Audit Log Model stored in `activity_logs`:
/// - id: string (document ID)
/// - switchId: string (e.g., "switch_1")
/// - switchName: string (e.g., "Living Room Light")
/// - deviceId: string (e.g., "esp32_001")
/// - userId: string? (acting user UID)
/// - userEmail: string? (acting user email)
/// - action: string ("ON", "OFF", "SCHEDULE_TRIGGER", "TIMER_TRIGGER")
/// - source: string ("mobile_app", "schedule", "timer", "hardware")
/// - timestamp: DateTime
@immutable
class ActivityLogModel {
  final String id;
  final String switchId;
  final String switchName;
  final String deviceId;
  final String? userId;
  final String? userEmail;
  final String action;
  final String source;
  final DateTime timestamp;

  const ActivityLogModel({
    required this.id,
    required this.switchId,
    required this.switchName,
    required this.deviceId,
    this.userId,
    this.userEmail,
    required this.action,
    required this.source,
    required this.timestamp,
  });

  factory ActivityLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return ActivityLogModel.fromMap(snapshot.id, data);
  }

  factory ActivityLogModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return ActivityLogModel(
      id: id,
      switchId: data['switchId'] as String? ?? 'unknown_switch',
      switchName: data['switchName'] as String? ?? 'Switch',
      deviceId: data['deviceId'] as String? ?? 'unknown_device',
      userId: data['userId'] as String?,
      userEmail: data['userEmail'] as String?,
      action: data['action'] as String? ?? 'UNKNOWN',
      source: data['source'] as String? ?? 'system',
      timestamp: parseTime(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'switchId': switchId,
      'switchName': switchName,
      'deviceId': deviceId,
      'action': action,
      'source': source,
      'timestamp': Timestamp.fromDate(timestamp),
    };
    if (userId != null) map['userId'] = userId;
    if (userEmail != null) map['userEmail'] = userEmail;
    return map;
  }
}
