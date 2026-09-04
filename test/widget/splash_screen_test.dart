import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/screens/splash_screen.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('Renders app title, subtitle, and custom status message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.dark,
          home: SplashScreen(statusMessage: 'Loading session...'),
        ),
      );

      expect(find.text('IoT Smart Switch'), findsOneWidget);
      expect(find.text('Cloud-Synchronized Appliance Automation'), findsOneWidget);
      expect(find.text('Loading session...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
