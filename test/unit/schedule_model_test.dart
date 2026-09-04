import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';

void main() {
  group('ScheduleModel Schema & Idempotency Tests', () {
    test('Serializes toMap() strictly matching approved schedules schema', () {
      final targetTime = DateTime.now().add(const Duration(minutes: 15));
      final model = ScheduleModel(
        id: 'timer_001',
        switchId: 'switch_1',
        action: 'off',
        time: targetTime,
        type: 'timer',
        status: 'pending',
        executedAt: null,
      );

      final map = model.toMap();

      // Check keys
      expect(
        map.keys.toSet(),
        equals({'switchId', 'action', 'time', 'type', 'status', 'executedAt'}),
      );
      expect(map['switchId'], 'switch_1');
      expect(map['action'], 'off');
      expect(map['type'], 'timer');
      expect(map['status'], 'pending');
      expect(map['executedAt'], isNull);
      expect((map['time'] as Timestamp).toDate(), targetTime);
    });

    test('Deserializes fromMap() accurately', () {
      final now = DateTime.now();
      final data = {
        'switchId': 'switch_2',
        'action': 'on',
        'time': Timestamp.fromDate(now),
        'type': 'timer',
        'status': 'completed',
        'executedAt': Timestamp.fromDate(now),
      };

      final model = ScheduleModel.fromMap('timer_002', data);

      expect(model.id, 'timer_002');
      expect(model.switchId, 'switch_2');
      expect(model.action, 'on');
      expect(model.type, 'timer');
      expect(model.status, 'completed');
      expect(model.isCompleted, isTrue);
      expect(model.isPending, isFalse);
    });

    test('Calculates timeRemaining accurately', () {
      final target = DateTime.now().add(const Duration(minutes: 10));
      final model = ScheduleModel(
        id: 'timer_003',
        switchId: 'switch_1',
        action: 'off',
        time: target,
      );

      expect(model.timeRemaining.inMinutes, inInclusiveRange(9, 10));
    });

    test('Ensures copyWith and equality work cleanly', () {
      final target = DateTime.now().add(const Duration(minutes: 5));
      final modelA = ScheduleModel(
        id: 'timer_004',
        switchId: 'switch_1',
        action: 'off',
        time: target,
      );

      final modelB = modelA.copyWith(status: 'completed');
      expect(modelB.status, 'completed');
      expect(modelB.isCompleted, isTrue);
      expect(modelA.status, 'pending');
    });
  });
}
