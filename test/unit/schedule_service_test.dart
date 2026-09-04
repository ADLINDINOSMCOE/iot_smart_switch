import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/services/schedule_service.dart';

class FakeScheduleService extends Fake implements ScheduleService {
  final List<ScheduleModel> inMemorySchedules = [];
  String? lastCancelledId;
  String? lastDeletedId;

  @override
  Future<String> createSchedule({
    required String switchId,
    required String action,
    required DateTime targetTime,
    String? userId,
    List<String> repeatDays = const [],
  }) async {
    final newId = 'schedule_${inMemorySchedules.length + 1}';
    final model = ScheduleModel(
      id: newId,
      switchId: switchId,
      action: action.toLowerCase(),
      time: targetTime.toUtc(),
      type: 'schedule',
      status: 'pending',
      executedAt: null,
      userId: userId,
      repeatDays: repeatDays,
    );
    inMemorySchedules.add(model);
    return newId;
  }

  @override
  Future<void> cancelSchedule(String scheduleId) async {
    lastCancelledId = scheduleId;
    final idx = inMemorySchedules.indexWhere((s) => s.id == scheduleId);
    if (idx != -1) {
      inMemorySchedules[idx] =
          inMemorySchedules[idx].copyWith(status: 'cancelled');
    }
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    lastDeletedId = scheduleId;
    inMemorySchedules.removeWhere((s) => s.id == scheduleId);
  }

  @override
  Stream<List<ScheduleModel>> streamSchedules({String? userId}) {
    return Stream.value(inMemorySchedules);
  }
}

void main() {
  group('ScheduleService Business Logic Tests', () {
    test('Creates schedule converting target time to canonical UTC', () async {
      final fake = FakeScheduleService();
      final localTarget = DateTime(2026, 8, 30, 19, 30); // 7:30 PM local

      final id = await fake.createSchedule(
        switchId: 'switch_1',
        action: 'on',
        targetTime: localTarget,
      );

      expect(id, 'schedule_1');
      expect(fake.inMemorySchedules.length, 1);
      final created = fake.inMemorySchedules.first;
      expect(created.switchId, 'switch_1');
      expect(created.action, 'on');
      expect(created.type, 'schedule');
      expect(created.status, 'pending');
      expect(created.time.isUtc, isTrue);
    });

    test('Cancels schedule idempotently', () async {
      final fake = FakeScheduleService();
      await fake.createSchedule(
        switchId: 'switch_2',
        action: 'off',
        targetTime: DateTime.now().add(const Duration(hours: 2)),
      );

      await fake.cancelSchedule('schedule_1');

      expect(fake.lastCancelledId, 'schedule_1');
      expect(fake.inMemorySchedules.first.status, 'cancelled');
      expect(fake.inMemorySchedules.first.isCancelled, isTrue);
    });

    test('Deletes schedule cleanly', () async {
      final fake = FakeScheduleService();
      await fake.createSchedule(
        switchId: 'switch_3',
        action: 'on',
        targetTime: DateTime.now().add(const Duration(hours: 3)),
      );

      expect(fake.inMemorySchedules.length, 1);
      await fake.deleteSchedule('schedule_1');

      expect(fake.lastDeletedId, 'schedule_1');
      expect(fake.inMemorySchedules, isEmpty);
    });
  });
}
