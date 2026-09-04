import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/services/timer_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';
import 'package:iot_smart_switch/widgets/set_timer_modal.dart';

class FakeTimerService extends Fake implements TimerService {
  String? createdSwitchId;
  String? createdAction;
  Duration? createdDuration;

  @override
  Future<String> createTimer({
    required String switchId,
    required String action,
    required Duration duration,
  }) async {
    createdSwitchId = switchId;
    createdAction = action;
    createdDuration = duration;
    return 'timer_mock_123';
  }
}

void main() {
  group('SetTimerModal Widget Tests', () {
    const testSwitch = SwitchModel(
      id: 'switch_1',
      name: 'Balcony Light',
      room: 'Balcony',
      isOn: true,
      deviceId: 'esp32_001',
    );

    Widget buildTestModal(TimerService timerService) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SetTimerModal(
            switchModel: testSwitch,
            timerService: timerService,
          ),
        ),
      );
    }

    testWidgets('Renders modal header, action segment, and duration chips',
        (WidgetTester tester) async {
      final fakeTimerService = FakeTimerService();
      await tester.pumpWidget(buildTestModal(fakeTimerService));
      await tester.pumpAndSettle();

      expect(find.text('Set Switch Timer'), findsOneWidget);
      expect(find.text('Balcony Light'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('Start 15 Min Timer'), findsOneWidget);
    });

    testWidgets('Allows selecting custom duration and invokes TimerService',
        (WidgetTester tester) async {
      final fakeTimerService = FakeTimerService();
      await tester.pumpWidget(buildTestModal(fakeTimerService));
      await tester.pumpAndSettle();

      // Tap '30 min' chip
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();

      expect(find.text('Start 30 Min Timer'), findsOneWidget);

      // Submit timer
      await tester.tap(find.text('Start 30 Min Timer'));
      await tester.pumpAndSettle();

      expect(fakeTimerService.createdSwitchId, 'switch_1');
      expect(fakeTimerService.createdAction, 'off');
      expect(fakeTimerService.createdDuration, const Duration(minutes: 30));
    });
  });
}
