import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_model.dart';

class TimerService {
  TimerService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static TimerService? _instance;
  static TimerService get instance => _instance ??= TimerService();

  CollectionReference<Map<String, dynamic>> get schedulesCollection =>
      _firestore.collection('schedules');

  CollectionReference<Map<String, dynamic>> get switchesCollection =>
      _firestore.collection('switches');

  /// Creates a new one-shot timer in the `schedules` collection
  Future<String> createTimer({
    required String switchId,
    required String action,
    required Duration duration,
  }) async {
    try {
      final targetTime = DateTime.now().add(duration);
      final docRef = schedulesCollection.doc();

      final timerPayload = ScheduleModel(
        id: docRef.id,
        switchId: switchId,
        action: action.toLowerCase(),
        time: targetTime,
        type: 'timer',
        status: 'pending',
        executedAt: null,
      );

      developer.log(
        'Creating one-shot timer for switch $switchId -> action: $action in ${duration.inSeconds}s (target: $targetTime)',
        name: 'TimerService',
      );

      await docRef.set(timerPayload.toMap());
      developer.log('Timer document created: ${docRef.id}', name: 'TimerService');
      return docRef.id;
    } catch (e) {
      developer.log('Failed to create timer: $e', name: 'TimerService');
      rethrow;
    }
  }

  /// Cancels an active timer
  Future<void> cancelTimer(String timerId) async {
    try {
      developer.log('Cancelling timer: $timerId', name: 'TimerService');
      await schedulesCollection.doc(timerId).update({
        'status': 'cancelled',
      });
      developer.log('Timer $timerId cancelled successfully.', name: 'TimerService');
    } catch (e) {
      developer.log('Failed to cancel timer $timerId: $e', name: 'TimerService');
      rethrow;
    }
  }

  /// Stream of all active (pending) timers
  Stream<List<ScheduleModel>> streamActiveTimers() {
    return schedulesCollection
        .where('type', isEqualTo: 'timer')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScheduleModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Stream of active timers for a specific switch
  Stream<List<ScheduleModel>> streamActiveTimersForSwitch(String switchId) {
    return schedulesCollection
        .where('switchId', isEqualTo: switchId)
        .where('type', isEqualTo: 'timer')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScheduleModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Executes the timer using an atomic Firestore transaction to guarantee idempotency.
  /// Exactly-once guarantee: If status != 'pending', the execution is aborted immediately.
  Future<bool> executeTimerTransaction(String timerId) async {
    final timerDocRef = schedulesCollection.doc(timerId);

    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final timerSnapshot = await transaction.get(timerDocRef);

        if (!timerSnapshot.exists || timerSnapshot.data() == null) {
          developer.log('Timer $timerId does not exist. Aborting execution.', name: 'TimerService');
          return false;
        }

        final timerData = timerSnapshot.data()!;
        final String currentStatus = timerData['status'] as String? ?? '';

        // Strict Idempotency Check
        if (currentStatus != 'pending') {
          developer.log(
            'Timer $timerId status is already "$currentStatus". Bypassing execution to avoid duplicate fire.',
            name: 'TimerService',
          );
          return false;
        }

        final String switchId = timerData['switchId'] as String? ?? '';
        final String action = (timerData['action'] as String? ?? 'off').toLowerCase();
        final bool targetIsOn = action == 'on';

        final switchDocRef = switchesCollection.doc(switchId);

        // Update target switch document (updating only the existing isOn field)
        transaction.update(switchDocRef, {
          'isOn': targetIsOn,
        });

        // Mark timer as completed with server timestamp
        transaction.update(timerDocRef, {
          'status': 'completed',
          'executedAt': FieldValue.serverTimestamp(),
        });

        developer.log(
          'Timer $timerId atomically executed -> Switch $switchId set to isOn: $targetIsOn',
          name: 'TimerService',
        );
        return true;
      });
    } catch (e, stackTrace) {
      developer.log(
        'Transaction execution failed for timer $timerId: $e',
        name: 'TimerService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
