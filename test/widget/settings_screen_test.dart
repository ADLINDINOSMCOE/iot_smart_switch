import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/screens/settings_screen.dart';
import 'package:iot_smart_switch/services/notification_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

class FakeNotificationServiceForSettings extends Fake
    implements NotificationService {
  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  group('SettingsScreen Widget Tests', () {
    testWidgets('Renders theme options, notifications, and system info',
        (WidgetTester tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
      final fakeNotif = FakeNotificationServiceForSettings();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SettingsScreen(
            themeModeNotifier: themeNotifier,
            notificationService: fakeNotif,
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Dark Mode (Deep Blue)'), findsOneWidget);
      expect(find.text('Light Mode'), findsOneWidget);
      expect(find.text('Push Notifications (FCM)'), findsOneWidget);
      expect(find.text('Share Device'), findsOneWidget);
      expect(find.text('About IoT Smart Switch'), findsOneWidget);

      // Tap Light Mode
      await tester.tap(find.text('Light Mode'));
      await tester.pump();

      expect(themeNotifier.value, ThemeMode.light);
    });
  });
}
