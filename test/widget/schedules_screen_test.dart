import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/screens/schedules_screen.dart';
import 'package:iot_smart_switch/services/schedule_service.dart';
import 'package:iot_smart_switch/services/switch_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

class FakeScheduleServiceForScreen extends Fake implements ScheduleService {
  final List<ScheduleModel> schedules;
  String? cancelledId;
  String? deletedId;

  FakeScheduleServiceForScreen(this.schedules);

  @override
  Stream<List<ScheduleModel>> streamSchedules({String? userId}) => Stream.value(schedules);

  @override
  Future<void> cancelSchedule(String scheduleId) async {
    cancelledId = scheduleId;
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    deletedId = scheduleId;
  }
}

class FakeSwitchServiceForScreen extends Fake implements SwitchService {}

void main() {
  group('SchedulesScreen Widget Tests', () {
    final sampleSchedules = [
      ScheduleModel(
        id: 'sched_1',
        switchId: 'switch_1',
        action: 'on',
        time: DateTime(2026, 8, 30, 8, 0),
        type: 'schedule',
        status: 'pending',
      ),
      ScheduleModel(
        id: 'sched_2',
        switchId: 'switch_2',
        action: 'off',
        time: DateTime(2026, 8, 30, 22, 30),
        type: 'schedule',
        status: 'completed',
        executedAt: DateTime(2026, 8, 30, 22, 30),
      ),
    ];

    Widget buildScreen(
      ScheduleService scheduleService, {
      Stream<List<ScheduleModel>>? customStream,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: SchedulesScreen(
          scheduleService: scheduleService,
          switchService: FakeSwitchServiceForScreen(),
          schedulesStream: customStream,
        ),
      );
    }

    testWidgets('Renders schedules list and action badges',
        (WidgetTester tester) async {
      final fakeSched = FakeScheduleServiceForScreen(sampleSchedules);

      await tester.pumpWidget(buildScreen(
        fakeSched,
        customStream: Stream.value(sampleSchedules),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Schedules & Automation'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('New Schedule'), findsOneWidget);
    });

    testWidgets('Filters by pending status', (WidgetTester tester) async {
      final fakeSched = FakeScheduleServiceForScreen(sampleSchedules);

      await tester.pumpWidget(buildScreen(
        fakeSched,
        customStream: Stream.value(sampleSchedules),
      ));
      await tester.pumpAndSettle();

      // Tap 'Pending' filter
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();

      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('COMPLETED'), findsNothing);
    });

    testWidgets('Renders empty state when list is empty',
        (WidgetTester tester) async {
      final fakeSched = FakeScheduleServiceForScreen([]);

      await tester.pumpWidget(buildScreen(
        fakeSched,
        customStream: Stream.value([]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Schedules Found'), findsOneWidget);
      expect(find.text('Create Schedule'), findsOneWidget);
    });
  });
}
