import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/screens/login_screen.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

void main() {
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('Renders all required login fields and buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Verify branding and title
      expect(find.text('IoT Smart Switch'), findsNWidgets(2)); // AppBar and BrandHeader
      expect(find.text('Sign In'), findsNWidgets(2)); // Mode switcher and Submit button
      expect(find.text('Create Account'), findsOneWidget);

      // Verify Form fields
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify Google Sign-In button
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('Toggles between Sign In and Create Account modes', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Initially in Sign In mode
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);

      // Tap 'Create Account' tab
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Submit button should change to 'Create Account'
      expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
    });

    testWidgets('Validates empty email and short password inputs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Tap submit with empty fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Expect validation error messages
      expect(find.text('Please enter your email address'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Validates invalid email format and password min length', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Enter invalid email and short password
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'invalid-email');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Expect format validation error messages
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });
  });
}
