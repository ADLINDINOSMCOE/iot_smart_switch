import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotswitch/main.dart';
import 'package:iotswitch/screens/home_screen.dart';
import 'package:iotswitch/screens/login_screen.dart';
import 'package:iotswitch/screens/signup_screen.dart';

void main() {
  group('App Widget Tests', () {
    testWidgets('App should start with SplashScreen', (WidgetTester tester) async {
      await tester.pumpWidget(const IoTSwitchApp());
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('Login Screen Widget Tests', () {
    testWidgets('LoginScreen should have email and password fields', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('LoginScreen should have Google Sign-In button', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('LoginScreen should have Remember Me checkbox', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      expect(find.text('Remember Me'), findsOneWidget);
    });
  });

  group('Signup Screen Widget Tests', () {
    testWidgets('SignupScreen should have all required fields', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      
      expect(find.byType(TextField), findsNWidgets(4)); // Name, email, password, confirm
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('I agree to the Terms & Privacy Policy'), findsOneWidget);
    });
  });

  group('Home Screen Widget Tests', () {
    testWidgets('HomeScreen should have bottom navigation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('HomeScreen should have add device button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('Widget Integration Tests', () {
    testWidgets('Navigation flow from Login to Signup', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Tap on Sign Up link
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Text field input should work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();
      
      expect(find.text('test@example.com'), findsOneWidget);
    });
  });
}