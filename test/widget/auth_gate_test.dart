import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/screens/auth_gate.dart';
import 'package:iot_smart_switch/screens/login_screen.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

void main() {
  group('AuthGate & Route Guard Tests', () {
    testWidgets('Displays LoginScreen when user is unauthenticated (null stream value)',
        (WidgetTester tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
      final controller = StreamController<User?>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AuthGate(
            themeModeNotifier: themeNotifier,
            authStream: controller.stream,
          ),
        ),
      );

      // Initially stream emits null (unauthenticated)
      controller.add(null);
      await tester.pumpAndSettle();

      // Verify that unauthenticated users are gated to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Sign in to manage your switches & hardware'),
        findsOneWidget,
      );

      await controller.close();
    });

    testWidgets('Shows loading indicator while auth stream is waiting',
        (WidgetTester tester) async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
      final controller = StreamController<User?>();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AuthGate(
            themeModeNotifier: themeNotifier,
            authStream: controller.stream,
          ),
        ),
      );

      // Without emitting data yet
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });
  });
}
