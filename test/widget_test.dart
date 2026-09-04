import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/main.dart';
import 'package:iot_smart_switch/screens/login_screen.dart';

void main() {
  testWidgets('App root initializes MaterialApp and renders AuthGate with LoginScreen',
      (WidgetTester tester) async {
    final authController = StreamController<User?>.broadcast();

    // Pump app with injected unauthenticated state
    await tester.pumpWidget(IoTSmartSwitchApp(authStream: authController.stream));
    authController.add(null);
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Sign in to manage your switches & hardware'),
      findsOneWidget,
    );

    await authController.close();
  });
}
