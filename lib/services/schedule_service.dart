import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'schedule_recurrence.dart';

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();

  factory ScheduleService() => _instance;

  ScheduleService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUid => _auth.currentUser?.uid;

  // =========================================================
  // SAVE SCHEDULE TO SUBCOLLECTION
  // =========================================================
  Future<void> addSchedule({
    required String deviceId,
    required int hour,
    required int minute,
    required List<String> days,
    required String action,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'User must be logged in to create a schedule.',
      );
    }

    final nextRunAt = ScheduleRecurrence.computeNextRunAt(
      hour: hour,
      minute: minute,
      days: days,
    );

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .add({
      'deviceId': deviceId,
      'hour': hour,
      'minute': minute,
      'days': days,
      'action': action,
      'enabled': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'timeZoneOffsetMinutes':
      DateTime.now().timeZoneOffset.inMinutes,
      'nextRunAt': Timestamp.fromDate(nextRunAt),
      'lastExecutedAt': null,
      'lastExecutionKey': null,
    });
  }

  // =========================================================
  // LEGACY SAVE SCHEDULE ADAPTER
  // =========================================================
  Future<void> addLegacySchedule({
    required String deviceId,
    required DateTime date,
    required String time,
    required List<String> repeat,
    required String action,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception(
        'User must be logged in to create a schedule.',
      );
    }

    final parts = time.split(':');

    final parsedHour = parts.isNotEmpty
        ? int.tryParse(parts[0]) ?? date.hour
        : date.hour;

    final parsedMinute = parts.length > 1
        ? int.tryParse(parts[1]) ?? date.minute
        : date.minute;

    final days = repeat.isEmpty
        ? <String>[]
        : repeat;

    final nextRunAt = ScheduleRecurrence.computeNextRunAt(
      hour: parsedHour,
      minute: parsedMinute,
      days: days,
    );

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .add({
      'deviceId': deviceId,
      'date': Timestamp.fromDate(date),
      'time': time,
      'hour': parsedHour,
      'minute': parsedMinute,
      'repeat': repeat,
      'days': days,
      'action': action,
      'enabled': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'timeZoneOffsetMinutes':
      DateTime.now().timeZoneOffset.inMinutes,
      'nextRunAt': Timestamp.fromDate(nextRunAt),
      'lastExecutedAt': null,
      'lastExecutionKey': null,
    });
  }

  // =========================================================
  // GET SCHEDULES FOR SPECIFIC DEVICE
  // =========================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedules(
      String deviceId,
      ) {
    if (deviceId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .orderBy(
      'createdAt',
      descending: true,
    )
        .snapshots();
  }

  // =========================================================
  // ENABLE / DISABLE SCHEDULE
  // =========================================================
  Future<void> updateScheduleStatus({
    required String deviceId,
    required String scheduleId,
    required bool enabled,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final scheduleRef = _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .doc(scheduleId);

    final snapshot = await scheduleRef.get();

    final data = snapshot.data() ?? {};

    final hour =
        (data['hour'] as num?)?.toInt() ?? 0;

    final minute =
        (data['minute'] as num?)?.toInt() ?? 0;

    final days = data['days'] is List
        ? List<dynamic>.from(
      data['days'] as List,
    )
        : <dynamic>[];

    final update = <String, dynamic>{
      'enabled': enabled,
      'lastUpdatedBy': uid,
      'lastUpdatedAt':
      FieldValue.serverTimestamp(),
    };

    if (enabled) {
      update['nextRunAt'] =
          Timestamp.fromDate(
            ScheduleRecurrence.computeNextRunAt(
              hour: hour,
              minute: minute,
              days: days,
            ),
          );
    }

    await scheduleRef.update(update);
  }

  // =========================================================
  // DELETE SCHEDULE
  // =========================================================
  Future<void> deleteSchedule({
    required String deviceId,
    required String scheduleId,
  }) async {
    final uid = _currentUid;

    if (uid == null) {
      throw Exception('User not authenticated');
    }

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .doc(scheduleId)
        .delete();
  }

  // =========================================================
  // POWER STATISTICS FOR A SPECIFIC DATE
  // =========================================================
  Future<Map<String, dynamic>> getPowerStatistics({
    required String deviceId,
    required DateTime date,
  }) async {
    // Start of selected day
    final dayStart = DateTime(
      date.year,
      date.month,
      date.day,
    );

    // Start of next day
    final dayEnd = dayStart.add(
      const Duration(days: 1),
    );

    // Get timer history for this switch
    final snapshot = await _db
        .collection('switches')
        .doc(deviceId)
        .collection('timerHistory')
        .orderBy('startedAt')
        .get();

    int totalRuntimeSeconds = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // -----------------------------------------------------
      // START TIME
      // -----------------------------------------------------
      final startedAtValue =
          data['startedAt'] ?? data['startTime'];

      if (startedAtValue is! Timestamp) {
        continue;
      }

      final startedAt =
      startedAtValue.toDate();

      // -----------------------------------------------------
      // END TIME
      // -----------------------------------------------------
      final stoppedAtValue =
          data['stoppedAt'] ?? data['endTime'];

      DateTime endedAt;

      if (stoppedAtValue is Timestamp) {
        endedAt = stoppedAtValue.toDate();
      } else {
        // If switch is currently running,
        // count runtime until now.
        if (data['status'] == 'active') {
          endedAt = DateTime.now();
        } else {
          continue;
        }
      }

      // -----------------------------------------------------
      // FIND OVERLAP WITH SELECTED DAY
      // -----------------------------------------------------
      final overlapStart =
      startedAt.isAfter(dayStart)
          ? startedAt
          : dayStart;

      final overlapEnd =
      endedAt.isBefore(dayEnd)
          ? endedAt
          : dayEnd;

      // Only count positive duration
      if (overlapEnd.isAfter(overlapStart)) {
        totalRuntimeSeconds +=
            overlapEnd
                .difference(overlapStart)
                .inSeconds;
      }
    }

    // -------------------------------------------------------
    // ENERGY CALCULATION
    //
    // Existing estimated device power = 60W
    //
    // Energy (kWh) =
    // runtime seconds × watts / 3,600,000
    // -------------------------------------------------------
    final energyKwh =
        (totalRuntimeSeconds * 60) / 3600000;

    return {
      'runtimeSeconds': totalRuntimeSeconds,
      'energyKwh': energyKwh,
    };
  }
}