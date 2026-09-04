import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/screens/signup_screen.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

void main() {
  group('SignupScreen Widget Tests', () {
    testWidgets('Renders all registration fields and buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SignupScreen(),
        ),
      );

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
    });

    testWidgets('Validates password match before submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SignupScreen(),
        ),
      );

      final emailFields = find.byType(TextFormField);
      await tester.enterText(emailFields.at(0), 'newuser@example.com');
      await tester.enterText(emailFields.at(1), 'password123');
      await tester.enterText(emailFields.at(2), 'mismatch456');

      final submitBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });
}
