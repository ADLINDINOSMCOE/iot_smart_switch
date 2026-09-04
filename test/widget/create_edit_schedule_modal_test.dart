import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/services/schedule_service.dart';
import 'package:iot_smart_switch/services/switch_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';
import 'package:iot_smart_switch/widgets/create_edit_schedule_modal.dart';

class FakeScheduleServiceForModal extends Fake implements ScheduleService {
  String? createdSwitchId;
  String? createdAction;
  DateTime? createdTargetTime;

  @override
  Future<String> createSchedule({
    required String switchId,
    required String action,
    required DateTime targetTime,
    String? userId,
    List<String> repeatDays = const [],
  }) async {
    createdSwitchId = switchId;
    createdAction = action;
    createdTargetTime = targetTime;
    return 'sched_mock_123';
  }
}

class FakeSwitchServiceForModal extends Fake implements SwitchService {
  @override
  Future<List<SwitchModel>> getSwitches({String? userId}) async {
    return [
      const SwitchModel(
        id: 'switch_1',
        name: 'Living Room Light',
        room: 'Living Room',
        isOn: false,
        deviceId: 'esp32_001',
      ),
      const SwitchModel(
        id: 'switch_2',
        name: 'Bedroom AC',
        room: 'Bedroom',
        isOn: true,
        deviceId: 'esp32_001',
      ),
    ];
  }
}

void main() {
  group('CreateEditScheduleModal Widget Tests', () {
    Widget buildModal(
      ScheduleService scheduleService,
      SwitchService switchService,
    ) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CreateEditScheduleModal(
            scheduleService: scheduleService,
            switchService: switchService,
          ),
        ),
      );
    }

    testWidgets('Renders schedule modal with switch, action, time, and timezone',
        (WidgetTester tester) async {
      final fakeSched = FakeScheduleServiceForModal();
      final fakeSwitch = FakeSwitchServiceForModal();

      await tester.pumpWidget(buildModal(fakeSched, fakeSwitch));
      await tester.pumpAndSettle();

      expect(find.text('Create New Schedule'), findsOneWidget);
      expect(find.text('Target Switch'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.textContaining('Timezone:'), findsOneWidget);
    });

    testWidgets('Submits schedule creation with selected action',
        (WidgetTester tester) async {
      final fakeSched = FakeScheduleServiceForModal();
      final fakeSwitch = FakeSwitchServiceForModal();

      await tester.pumpWidget(buildModal(fakeSched, fakeSwitch));
      await tester.pumpAndSettle();

      // Switch action to Turn OFF
      await tester.tap(find.text('Turn OFF'));
      await tester.pumpAndSettle();

      // Submit
      final submitFinder = find.byType(ElevatedButton);
      expect(submitFinder, findsOneWidget);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(fakeSched.createdSwitchId, 'switch_1');
      expect(fakeSched.createdAction, 'off');
      expect(fakeSched.createdTargetTime, isNotNull);
    });
  });
}
