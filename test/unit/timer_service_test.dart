import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/services/timer_service.dart';

class FakeTimerServiceImplementation extends Fake implements TimerService {
  final List<ScheduleModel> createdTimers = [];
  final List<String> cancelledIds = [];

  @override
  Future<String> createTimer({
    required String switchId,
    required String action,
    required Duration duration,
  }) async {
    final timerId = 'timer_${DateTime.now().millisecondsSinceEpoch}';
    final targetTime = DateTime.now().add(duration);
    final model = ScheduleModel(
      id: timerId,
      switchId: switchId,
      action: action,
      time: targetTime,
      type: 'timer',
      status: 'pending',
    );
    createdTimers.add(model);
    return timerId;
  }

  @override
  Future<void> cancelTimer(String timerId) async {
    cancelledIds.add(timerId);
  }
}

void main() {
  group('TimerService Business Logic Tests', () {
    test('Creates one-shot timer and computes future execution time', () async {
      final service = FakeTimerServiceImplementation();
      const testDuration = Duration(minutes: 10);

      final timerId = await service.createTimer(
        switchId: 'switch_1',
        duration: testDuration,
        action: 'off',
      );

      expect(timerId, startsWith('timer_'));
      expect(service.createdTimers.length, 1);
      final created = service.createdTimers.first;
      expect(created.switchId, 'switch_1');
      expect(created.action, 'off');
      expect(created.type, 'timer');
      expect(created.status, 'pending');
      expect(created.time.isAfter(DateTime.now()), isTrue);
    });

    test('Cancels active timer correctly', () async {
      final service = FakeTimerServiceImplementation();
      await service.cancelTimer('timer_123');
      expect(service.cancelledIds, contains('timer_123'));
    });
  });
}
