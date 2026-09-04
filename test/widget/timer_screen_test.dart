import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/screens/timer_screen.dart';
import 'package:iot_smart_switch/services/switch_service.dart';
import 'package:iot_smart_switch/services/timer_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

class FakeTimerServiceForScreen extends Fake implements TimerService {
  final List<ScheduleModel> timers;
  String? cancelledId;

  FakeTimerServiceForScreen(this.timers);

  @override
  Stream<List<ScheduleModel>> streamActiveTimers() {
    return Stream.value(timers);
  }

  @override
  Future<void> cancelTimer(String timerId) async {
    cancelledId = timerId;
  }
}

class FakeSwitchServiceForTimerScreen extends Fake implements SwitchService {
  @override
  Stream<List<SwitchModel>> streamSwitches({String? userId}) {
    return Stream.value([
      const SwitchModel(
        id: 'switch_1',
        name: 'Living Room Light',
        room: 'Living Room',
        isOn: true,
        deviceId: 'esp32_001',
      ),
    ]);
  }
}

void main() {
  group('TimerScreen Widget Tests', () {
    testWidgets('Renders active timer cards and cancel button',
        (WidgetTester tester) async {
      final activeTimer = ScheduleModel(
        id: 'timer_test_1',
        switchId: 'switch_1',
        action: 'off',
        time: DateTime.now().add(const Duration(minutes: 5)),
        type: 'timer',
        status: 'pending',
      );

      final fakeTimerService = FakeTimerServiceForScreen([activeTimer]);
      final fakeSwitchService = FakeSwitchServiceForTimerScreen();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TimerScreen(
            timerService: fakeTimerService,
            switchService: fakeSwitchService,
            enableCountdownTicker: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Timers'), findsOneWidget);
      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('WILL TURN OFF'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeTimerService.cancelledId, 'timer_test_1');
    });

    testWidgets('Renders empty state when no active timers exist',
        (WidgetTester tester) async {
      final fakeTimerService = FakeTimerServiceForScreen([]);
      final fakeSwitchService = FakeSwitchServiceForTimerScreen();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TimerScreen(
            timerService: fakeTimerService,
            switchService: fakeSwitchService,
            enableCountdownTicker: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Active Timers'), findsOneWidget);
    });
  });
}
