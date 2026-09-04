import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/device_model.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/screens/home_screen.dart';
import 'package:iot_smart_switch/services/notification_service.dart';
import 'package:iot_smart_switch/services/switch_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';
import 'package:iot_smart_switch/widgets/home_switch_card.dart';

// Fake User for authenticated widget tests
class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_user_123';
  @override
  String? get email => 'tester@example.com';
  @override
  String? get displayName => 'Test User';
  @override
  String? get photoURL => null;
  @override
  bool get emailVerified => true;
  @override
  List<UserInfo> get providerData => [];
}

// Fake SwitchService to simulate success and failure behaviors
class FakeSwitchService extends Fake implements SwitchService {
  final List<SwitchModel> switches;
  bool shouldFailWrite = false;
  String? lastUpdatedId;
  bool? lastUpdatedState;

  FakeSwitchService(this.switches);

  @override
  Stream<List<SwitchModel>> streamSwitches({String? userId}) {
    return Stream.value(switches);
  }

  @override
  Future<void> setSwitchState({
    required String switchId,
    required bool isOn,
  }) async {
    if (shouldFailWrite) {
      throw Exception('Simulated Firestore write failure');
    }
    lastUpdatedId = switchId;
    lastUpdatedState = isOn;
  }

  @override
  Future<void> seedSampleSwitches({String? userId, bool overwrite = false}) async {}
}

class FakeNotificationServiceForTest extends Fake
    implements NotificationService {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> registerDeviceToken(String userId) async => 'fake_token';

  @override
  void setupMessageHandlers({
    required void Function(String target, Map<String, dynamic> data) onNavigate,
  }) {}
}

void main() {
  final fakeUser = FakeUser();
  final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  final sampleData = [
    const SwitchModel(
      id: 'switch_1',
      name: 'Living Room Light',
      room: 'Living Room',
      isOn: true,
      deviceId: 'esp32_001',
    ),
    const SwitchModel(
      id: 'switch_2',
      name: 'Ceiling Fan',
      room: 'Living Room',
      isOn: false,
      deviceId: 'esp32_001',
    ),
    const SwitchModel(
      id: 'switch_3',
      name: 'Kitchen Lamp',
      room: 'Kitchen',
      isOn: false,
      deviceId: 'esp32_001',
    ),
  ];

  Widget buildTestScreen({
    required SwitchService switchService,
    Stream<List<SwitchModel>>? customStream,
    Stream<List<ScheduleModel>>? customTimersStream,
    Stream<List<DeviceModel>>? customDevicesStream,
  }) {
    final defaultSwitchesStream = switchService is FakeSwitchService
        ? Stream.value(switchService.switches)
        : null;

    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: HomeScreen(
        user: fakeUser,
        themeModeNotifier: themeNotifier,
        switchService: switchService,
        notificationService: FakeNotificationServiceForTest(),
        switchesStream: customStream ?? defaultSwitchesStream,
        timersStream: customTimersStream ?? Stream.value([]),
        devicesStream: customDevicesStream ?? Stream.value([]),
        enableCountdownTicker: false,
      ),
    );
  }

  group('HomeScreen Widget & Optimistic Update Tests', () {
    testWidgets('Renders metrics, room groupings, and all switch cards',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchService(sampleData);

      await tester.pumpWidget(buildTestScreen(switchService: fakeService));
      await tester.pumpAndSettle();

      // Metrics verification
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Total: 3
      expect(find.text('2'), findsOneWidget); // Rooms: 2

      // Room grouping headers
      expect(find.text('Living Room'), findsAtLeastNWidgets(1));
      expect(find.text('Kitchen'), findsAtLeastNWidgets(1));

      // Switch cards
      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Ceiling Fan'), findsOneWidget);
      expect(find.text('Kitchen Lamp'), findsOneWidget);
    });

    testWidgets('Filters switches when a room chip is selected',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchService(sampleData);

      await tester.pumpWidget(buildTestScreen(switchService: fakeService));
      await tester.pumpAndSettle();

      // Tap 'Kitchen (1)' chip
      await tester.tap(find.text('Kitchen (1)'));
      await tester.pumpAndSettle();

      // Only Kitchen switches should remain visible
      expect(find.text('Kitchen Lamp'), findsOneWidget);
      expect(find.text('Living Room Light'), findsNothing);
      expect(find.text('Ceiling Fan'), findsNothing);

      // Tap 'All Rooms (3)' to reset filter
      await tester.tap(find.text('All Rooms (3)'));
      await tester.pumpAndSettle();

      // All switches back
      expect(find.text('Kitchen Lamp'), findsOneWidget);
      expect(find.text('Living Room Light'), findsOneWidget);
      expect(find.text('Ceiling Fan'), findsOneWidget);
    });

    testWidgets('Optimistically toggles switch and applies Firestore update',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchService(sampleData);

      await tester.pumpWidget(buildTestScreen(switchService: fakeService));
      await tester.pumpAndSettle();

      // Find switch for 'Ceiling Fan' (currently OFF)
      final ceilingFanCardFinder = find.widgetWithText(HomeSwitchCard, 'Ceiling Fan');
      expect(ceilingFanCardFinder, findsOneWidget);

      final switchInCard = find.descendant(
        of: ceilingFanCardFinder,
        matching: find.byType(Switch),
      );

      // Ensure visible and tap to toggle ON
      await tester.ensureVisible(switchInCard);
      await tester.pumpAndSettle();
      await tester.tap(switchInCard);
      await tester.pump(); // Frame 1: Optimistic state applied immediately

      expect(fakeService.lastUpdatedId, 'switch_2');
      expect(fakeService.lastUpdatedState, isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('Rolls back optimistic state and displays SnackBar on Firestore write error',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchService(sampleData)..shouldFailWrite = true;

      await tester.pumpWidget(buildTestScreen(switchService: fakeService));
      await tester.pumpAndSettle();

      // Find 'Ceiling Fan' (initially OFF)
      final ceilingFanCardFinder = find.widgetWithText(HomeSwitchCard, 'Ceiling Fan');
      final switchInCard = find.descendant(
        of: ceilingFanCardFinder,
        matching: find.byType(Switch),
      );

      // Ensure visible and tap toggle -> will fail
      await tester.ensureVisible(switchInCard);
      await tester.pumpAndSettle();
      await tester.tap(switchInCard);
      await tester.pumpAndSettle();

      // Verify SnackBar error message and rollback notification
      expect(
        find.text('Failed to update "Ceiling Fan". Reverted to OFF.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Renders empty state when no switches are in Firestore',
        (WidgetTester tester) async {
      final fakeService = FakeSwitchService([]);

      await tester.pumpWidget(buildTestScreen(switchService: fakeService));
      await tester.pumpAndSettle();

      expect(find.text('No Switches Configured Yet'), findsOneWidget);
      expect(find.text('Seed Default Switches'), findsOneWidget);
    });
  });
}
