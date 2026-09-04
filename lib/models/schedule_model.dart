import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Authoritative Schedule / Timer Model:
/// - id: string (document ID)
/// - switchId: string (references switches doc)
/// - action: "on" | "off"
/// - time: timestamp (target execution time)
/// - type: "timer" | "schedule"
/// - status: "pending" | "completed" | "cancelled"
/// - executedAt: timestamp | null
/// - userId: string? (creator user UID)
/// - repeatDays: list of strings (e.g. ['mon', 'wed', 'fri'])
@immutable
class ScheduleModel {
  final String id;
  final String switchId;
  final String action; // "on" | "off"
  final DateTime time;
  final String type; // "timer" | "schedule"
  final String status; // "pending" | "completed" | "cancelled"
  final DateTime? executedAt;
  final String? userId;
  final List<String> repeatDays;

  const ScheduleModel({
    required this.id,
    required this.switchId,
    required this.action,
    required this.time,
    this.type = 'timer',
    this.status = 'pending',
    this.executedAt,
    this.userId,
    this.repeatDays = const [],
  });

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isTimer => type == 'timer';
  bool get isRepeating => repeatDays.isNotEmpty;

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(time)) {
      return Duration.zero;
    }
    return time.difference(now);
  }

  factory ScheduleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return ScheduleModel.fromMap(snapshot.id, data);
  }

  factory ScheduleModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parsedTime;
    final rawTime = data['time'];
    if (rawTime is Timestamp) {
      parsedTime = rawTime.toDate();
    } else if (rawTime is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is String) {
      parsedTime = DateTime.tryParse(rawTime) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    DateTime? parsedExecutedAt;
    final rawExecutedAt = data['executedAt'];
    if (rawExecutedAt is Timestamp) {
      parsedExecutedAt = rawExecutedAt.toDate();
    } else if (rawExecutedAt is int) {
      parsedExecutedAt = DateTime.fromMillisecondsSinceEpoch(rawExecutedAt);
    } else if (rawExecutedAt is String) {
      parsedExecutedAt = DateTime.tryParse(rawExecutedAt);
    }

    final rawDays = data['repeatDays'];
    final List<String> days = rawDays is List
        ? rawDays.whereType<String>().toList()
        : const [];

    return ScheduleModel(
      id: id,
      switchId: data['switchId'] as String? ?? '',
      action: (data['action'] as String? ?? 'off').toLowerCase(),
      time: parsedTime,
      type: data['type'] as String? ?? 'timer',
      status: data['status'] as String? ?? 'pending',
      executedAt: parsedExecutedAt,
      userId: data['userId'] as String?,
      repeatDays: days,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'switchId': switchId,
      'action': action,
      'time': Timestamp.fromDate(time),
      'type': type,
      'status': status,
      'executedAt':
          executedAt != null ? Timestamp.fromDate(executedAt!) : null,
    };
    if (userId != null) {
      map['userId'] = userId;
    }
    if (repeatDays.isNotEmpty) {
      map['repeatDays'] = repeatDays;
    }
    return map;
  }

  ScheduleModel copyWith({
    String? id,
    String? switchId,
    String? action,
    DateTime? time,
    String? type,
    String? status,
    DateTime? executedAt,
    String? userId,
    List<String>? repeatDays,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      switchId: switchId ?? this.switchId,
      action: action ?? this.action,
      time: time ?? this.time,
      type: type ?? this.type,
      status: status ?? this.status,
      executedAt: executedAt ?? this.executedAt,
      userId: userId ?? this.userId,
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleModel &&
        other.id == id &&
        other.switchId == switchId &&
        other.action == action &&
        other.time == time &&
        other.type == type &&
        other.status == status &&
        other.executedAt == executedAt &&
        other.userId == userId &&
        listEquals(other.repeatDays, repeatDays);
  }

  @override
  int get hashCode => Object.hash(
        id,
        switchId,
        action,
        time,
        type,
        status,
        executedAt,
        userId,
        Object.hashAll(repeatDays),
      );

  @override
  String toString() {
    return 'ScheduleModel(id: $id, switchId: $switchId, action: $action, '
        'time: $time, type: $type, status: $status, executedAt: $executedAt, '
        'userId: $userId, repeatDays: $repeatDays)';
  }
}
