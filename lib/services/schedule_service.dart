import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUid => _auth.currentUser?.uid;

  // ==============================================
  // SAVE SCHEDULE TO SUBCOLLECTION
  // ==============================================
  Future<void> addSchedule({
    required String deviceId,
    required int hour,
    required int minute,
    required List<String> days,
    required String action,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be logged in to create a schedule.');
    }

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
    });
  }

  // ==============================================
  // LEGACY SAVE SCHEDULE ADAPTER
  // ==============================================
  Future<void> addLegacySchedule({
    required String deviceId,
    required DateTime date,
    required String time,
    required List<String> repeat,
    required String action,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      throw Exception('User must be logged in to create a schedule.');
    }

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .add({
      'deviceId': deviceId,
      'date': Timestamp.fromDate(date),
      'time': time,
      'repeat': repeat,
      'action': action,
      'enabled': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==============================================
  // GET SCHEDULES FOR SPECIFIC DEVICE (SUBCOLLECTION)
  // ==============================================
  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedules(String deviceId) {
    if (deviceId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ==============================================
  // ENABLE / DISABLE SCHEDULE
  // ==============================================
  Future<void> updateScheduleStatus({
    required String deviceId,
    required String scheduleId,
    required bool enabled,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .doc(scheduleId)
        .update({
      'enabled': enabled,
      'lastUpdatedBy': uid,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==============================================
  // DELETE SCHEDULE
  // ==============================================
  Future<void> deleteSchedule({
    required String deviceId,
    required String scheduleId,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('User not authenticated');

    await _db
        .collection('switches')
        .doc(deviceId)
        .collection('schedules')
        .doc(scheduleId)
        .delete();
  }
}
