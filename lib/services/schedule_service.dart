import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';

class ScheduleService {
  ScheduleService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static ScheduleService? _instance;
  static ScheduleService get instance => _instance ??= ScheduleService();

  CollectionReference<Map<String, dynamic>> get schedulesCollection =>
      _firestore.collection('schedules');

  CollectionReference<Map<String, dynamic>> get switchesCollection =>
      _firestore.collection('switches');

  /// Creates a new scheduled action in the `schedules` collection.
  /// Converts the given DateTime to canonical UTC before storage.
  Future<String> createSchedule({
    required String switchId,
    required String action,
    required DateTime targetTime,
    String? userId,
    List<String> repeatDays = const [],
  }) async {
    try {
      final docRef = schedulesCollection.doc();
      final schedulePayload = ScheduleModel(
        id: docRef.id,
        switchId: switchId,
        action: action.toLowerCase(),
        time: targetTime.toUtc(),
        type: 'schedule',
        status: 'pending',
        executedAt: null,
        userId: userId,
        repeatDays: repeatDays,
      );

      developer.log(
        'Creating schedule for switch $switchId -> action: $action at ${targetTime.toUtc()} (UTC)',
        name: 'ScheduleService',
      );

      await docRef.set(schedulePayload.toMap());
      developer.log('Schedule created: ${docRef.id}', name: 'ScheduleService');
      return docRef.id;
    } catch (e) {
      developer.log('Failed to create schedule: $e', name: 'ScheduleService');
      rethrow;
    }
  }

  /// Updates an existing schedule
  Future<void> updateSchedule({
    required String scheduleId,
    required String action,
    required DateTime targetTime,
    List<String>? repeatDays,
  }) async {
    try {
      developer.log(
        'Updating schedule $scheduleId -> action: $action at $targetTime',
        name: 'ScheduleService',
      );
      final updateData = <String, dynamic>{
        'action': action.toLowerCase(),
        'time': Timestamp.fromDate(targetTime.toUtc()),
        'status': 'pending',
      };
      if (repeatDays != null) {
        updateData['repeatDays'] = repeatDays;
      }
      await schedulesCollection.doc(scheduleId).update(updateData);
      developer.log('Schedule $scheduleId updated.', name: 'ScheduleService');
    } catch (e) {
      developer.log('Failed to update schedule $scheduleId: $e', name: 'ScheduleService');
      rethrow;
    }
  }

  /// Cancels an existing schedule
  Future<void> cancelSchedule(String scheduleId) async {
    try {
      developer.log('Cancelling schedule: $scheduleId', name: 'ScheduleService');
      await schedulesCollection.doc(scheduleId).update({
        'status': 'cancelled',
      });
      developer.log('Schedule $scheduleId cancelled.', name: 'ScheduleService');
    } catch (e) {
      developer.log('Failed to cancel schedule $scheduleId: $e', name: 'ScheduleService');
      rethrow;
    }
  }

  /// Deletes a schedule document permanently
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      developer.log('Deleting schedule: $scheduleId', name: 'ScheduleService');
      await schedulesCollection.doc(scheduleId).delete();
      developer.log('Schedule $scheduleId deleted.', name: 'ScheduleService');
    } catch (e) {
      developer.log('Failed to delete schedule $scheduleId: $e', name: 'ScheduleService');
      rethrow;
    }
  }

  /// Stream of all schedules (ordered by target time) with optional user filtering
  Stream<List<ScheduleModel>> streamSchedules({String? userId}) {
    return schedulesCollection
        .orderBy('time', descending: false)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => ScheduleModel.fromFirestore(doc))
          .toList();
      if (userId == null) return docs;
      return docs.where((s) => s.userId == null || s.userId == userId).toList();
    });
  }

  /// Stream of schedules for a specific switch
  Stream<List<ScheduleModel>> streamSchedulesForSwitch(String switchId) {
    return schedulesCollection
        .where('switchId', isEqualTo: switchId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ScheduleModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.time.compareTo(b.time));
      return list;
    });
  }

  /// Executes a schedule using an atomic Firestore transaction.
  /// Exactly-once idempotency: Aborts immediately if status != 'pending'.
  Future<bool> executeScheduleTransaction(String scheduleId) async {
    final scheduleDocRef = schedulesCollection.doc(scheduleId);

    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final snap = await transaction.get(scheduleDocRef);
        if (!snap.exists || snap.data() == null) {
          developer.log('Schedule $scheduleId not found.', name: 'ScheduleService');
          return false;
        }

        final data = snap.data()!;
        final String status = data['status'] as String? ?? '';

        // Strict Idempotency Check
        if (status != 'pending') {
          developer.log(
            'Schedule $scheduleId is already "$status". Bypassing execution.',
            name: 'ScheduleService',
          );
          return false;
        }

        final String switchId = data['switchId'] as String? ?? '';
        final String action = (data['action'] as String? ?? 'off').toLowerCase();
        final bool targetIsOn = action == 'on';

        final switchDocRef = switchesCollection.doc(switchId);

        // Update target switch isOn field
        transaction.update(switchDocRef, {
          'isOn': targetIsOn,
        });

        // Mark schedule as completed
        transaction.update(scheduleDocRef, {
          'status': 'completed',
          'executedAt': FieldValue.serverTimestamp(),
        });

        developer.log(
          'Schedule $scheduleId executed -> Switch $switchId set to isOn: $targetIsOn',
          name: 'ScheduleService',
        );
        return true;
      });
    } catch (e, stackTrace) {
      developer.log(
        'Failed to execute schedule transaction $scheduleId: $e',
        name: 'ScheduleService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
