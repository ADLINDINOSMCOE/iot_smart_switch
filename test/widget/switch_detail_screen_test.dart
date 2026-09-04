import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/activity_log_model.dart';
import 'package:iot_smart_switch/models/device_model.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/screens/switch_detail_screen.dart';
import 'package:iot_smart_switch/services/activity_log_service.dart';
import 'package:iot_smart_switch/services/switch_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

class FakeSwitchServiceForDetail extends Fake implements SwitchService {
  bool? lastState;
  final SwitchModel initialSwitch;

  FakeSwitchServiceForDetail(this.initialSwitch);

  @override
  Stream<SwitchModel?> streamSwitch(String switchId) {
    return Stream.value(initialSwitch);
  }

  @override
  Future<void> setSwitchState({required String switchId, required bool isOn}) async {
    lastState = isOn;
  }
}

class FakeActivityLogServiceForDetail extends Fake implements ActivityLogService {
  @override
  Future<void> logAction({
    required String switchId,
    required String switchName,
    required String deviceId,
    String? userId,
    String? userEmail,
    required String action,
    required String source,
  }) async {}

  @override
  Stream<List<ActivityLogModel>> streamLogs({
    String? switchId,
    String? userId,
    int limit = 20,
  }) {
    return Stream.value([]);
  }
}

void main() {
  group('SwitchDetailScreen Widget Tests', () {
    const testSwitch = SwitchModel(
      id: 'switch_1',
      name: 'Living Room Main Light',
      room: 'Living Room',
      isOn: true,
      deviceId: 'esp32_001',
    );

    final onlineDevice = DeviceModel(
      deviceId: 'esp32_001',
      lastSeen: DateTime.now(),
      actualStates: const {'switch_1': true},
    );

    testWidgets('Renders switch details, room, deviceId, and synced hardware telemetry',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchServiceForDetail(testSwitch);
      final fakeLogService = FakeActivityLogServiceForDetail();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SwitchDetailScreen(
            switchModel: testSwitch,
            deviceModel: onlineDevice,
            switchService: fakeService,
            activityLogService: fakeLogService,
            enableCountdownTicker: false,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Living Room Main Light'), findsWidgets);
      expect(find.text('Living Room'), findsWidgets);
      expect(find.text('ON'), findsOneWidget);
      expect(find.text('TAP TO TURN OFF'), findsOneWidget);
      expect(find.text('Controller Online (esp32_001)'), findsOneWidget);
      expect(find.text('Physical relay confirms state is ON.'), findsOneWidget);
      expect(find.text('Set Timer'), findsOneWidget);
      expect(find.text('Add Schedule'), findsOneWidget);
    });

    testWidgets('Toggles switch state using power button widget',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchServiceForDetail(testSwitch);
      final fakeLogService = FakeActivityLogServiceForDetail();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SwitchDetailScreen(
            switchModel: testSwitch,
            deviceModel: onlineDevice,
            switchService: fakeService,
            activityLogService: fakeLogService,
            enableCountdownTicker: false,
          ),
        ),
      );

      await tester.pump();

      final powerButton = find.byIcon(Icons.power_settings_new_rounded);
      expect(powerButton, findsOneWidget);

      await tester.tap(powerButton);
      await tester.pump();

      expect(fakeService.lastState, isFalse);
    });
  });
}
