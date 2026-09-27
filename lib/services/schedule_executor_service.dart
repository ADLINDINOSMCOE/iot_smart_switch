import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'schedule_recurrence.dart';

class ScheduleExecutorService {
  static final ScheduleExecutorService _instance =
  ScheduleExecutorService._internal();

  factory ScheduleExecutorService() => _instance;

  ScheduleExecutorService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FirestoreService _firestoreService =
  FirestoreService();

  Timer? _timer;

  bool _isRunning = false;

  // =========================================================
  // START
  // =========================================================

  void start() {
    if (_timer != null) {
      return;
    }

    // Check immediately.
    _checkSchedules();

    // Then check every 10 seconds.
    _timer = Timer.periodic(
      const Duration(seconds: 10),
          (_) {
        _checkSchedules();
      },
    );
  }

  // =========================================================
  // STOP
  // =========================================================

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // =========================================================
  // CHECK ALL SCHEDULES
  // =========================================================

  Future<void> _checkSchedules() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;

    try {
      final now = DateTime.now();

      final devicesSnapshot =
      await _db.collection('switches').get();

      for (final deviceDoc in devicesSnapshot.docs) {
        await _checkDeviceSchedules(
          deviceDoc.id,
          now,
        );
      }
    } catch (e) {
      debugPrint(
        'SCHEDULE EXECUTOR ERROR: $e',
      );
    } finally {
      _isRunning = false;
    }
  }

  // =========================================================
  // CHECK DEVICE SCHEDULES
  // =========================================================

  Future<void> _checkDeviceSchedules(
      String deviceId,
      DateTime now,
      ) async {
    final schedulesSnapshot = await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .where(
      'enabled',
      isEqualTo: true,
    )
        .get();

    for (final scheduleDoc
    in schedulesSnapshot.docs) {
      await _executeIfDue(
        deviceId,
        scheduleDoc,
        now,
      );
    }
  }

  // =========================================================
  // EXECUTE IF DUE
  // =========================================================

  Future<void> _executeIfDue(
      String deviceId,
      QueryDocumentSnapshot<Map<String, dynamic>>
      scheduleDoc,
      DateTime now,
      ) async {
    final data = scheduleDoc.data();

    final hour =
    (data['hour'] as num?)?.toInt();

    final minute =
    (data['minute'] as num?)?.toInt();

    if (hour == null || minute == null) {
      return;
    }

    final days = data['days'] is List
        ? List<dynamic>.from(
      data['days'] as List,
    )
        : <dynamic>[];

    final nextRunValue =
    data['nextRunAt'];

    DateTime? nextRunAt;

    if (nextRunValue is Timestamp) {
      nextRunAt =
          nextRunValue.toDate();
    }

    if (nextRunAt == null) {
      await _updateNextRun(
        deviceId,
        scheduleDoc.id,
        hour,
        minute,
        days,
        now,
      );

      return;
    }

    // Not due yet.
    if (now.isBefore(nextRunAt)) {
      return;
    }

    // =======================================================
    // EXECUTION KEY
    // =======================================================

    final executionKey =
    ScheduleRecurrence.executionKey(
      nextRunAt,
    );

    final previousKey =
    data['lastExecutionKey']
        ?.toString();

    // Already executed.
    if (previousKey == executionKey) {
      await _updateNextRun(
        deviceId,
        scheduleDoc.id,
        hour,
        minute,
        days,
        nextRunAt,
      );

      return;
    }

    // =======================================================
    // ACTION
    // =======================================================

    final action =
    data['action']
        ?.toString()
        .toLowerCase();

    final bool turnOn =
        action == 'on';

    try {
      // Actually change the switch.
      await _firestoreService.updateSwitch(
        deviceId,
        turnOn,
      );

      // =====================================================
      // SAVE EXECUTION
      // =====================================================

      final followingRun =
      ScheduleRecurrence
          .computeFollowingRunAt(
        justExecuted: nextRunAt,
        hour: hour,
        minute: minute,
        days: days,
      );

      await _db
          .collection('switches')
          .doc(deviceId)
          .collection('schedules')
          .doc(scheduleDoc.id)
          .update({
        'lastExecutedAt':
        Timestamp.fromDate(
          nextRunAt,
        ),
        'lastExecutionKey':
        executionKey,
        'nextRunAt':
        Timestamp.fromDate(
          followingRun,
        ),
      });

      debugPrint(
        'SCHEDULE EXECUTED: '
            '$deviceId → '
            '${turnOn ? 'ON' : 'OFF'} '
            'at $nextRunAt',
      );
    } catch (e) {
      debugPrint(
        'SCHEDULE EXECUTION FAILED: '
            '$deviceId → $e',
      );
    }
  }

  // =========================================================
  // UPDATE NEXT RUN
  // =========================================================

  Future<void> _updateNextRun(
      String deviceId,
      String scheduleId,
      int hour,
      int minute,
      List<dynamic> days,
      DateTime from,
      ) async {
    final nextRun =
    ScheduleRecurrence.computeNextRunAt(
      hour: hour,
      minute: minute,
      days: days,
      from: from,
    );

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .doc(scheduleId)
        .update({
      'nextRunAt':
      Timestamp.fromDate(nextRun),
    });
  }
}