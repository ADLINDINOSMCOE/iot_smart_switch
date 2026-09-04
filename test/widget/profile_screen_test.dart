import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/screens/profile_screen.dart';
import 'package:iot_smart_switch/services/auth_service.dart';
import 'package:iot_smart_switch/services/notification_service.dart';
import 'package:iot_smart_switch/theme/app_theme.dart';

class FakeUserForProfile extends Fake implements User {
  @override
  String get uid => 'user_profile_123';
  @override
  String? get displayName => 'Adlin Thomas';
  @override
  String? get email => 'adlin@example.com';
  @override
  bool get emailVerified => false;
  @override
  String? get photoURL => null;
  @override
  List<UserInfo> get providerData => [];
}

class FakeAuthServiceForProfile extends Fake implements AuthService {
  bool signOutCalled = false;
  bool passwordResetCalled = false;
  bool verificationEmailCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetCalled = true;
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationEmailCalled = true;
  }
}

class FakeNotificationServiceForProfile extends Fake
    implements NotificationService {
  @override
  Future<void> unregisterDeviceToken(String userId) async {}
}

void main() {
  group('ProfileScreen Widget Tests', () {
    final fakeUser = FakeUserForProfile();

    testWidgets('Renders user info, verification action, and sign-out dialog',
        (WidgetTester tester) async {
      final fakeAuth = FakeAuthServiceForProfile();
      final fakeNotif = FakeNotificationServiceForProfile();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(
            user: fakeUser,
            authService: fakeAuth,
            notificationService: fakeNotif,
          ),
        ),
      );

      expect(find.text('Account Profile'), findsOneWidget);
      expect(find.text('Adlin Thomas'), findsOneWidget);
      expect(find.text('adlin@example.com'), findsOneWidget);
      expect(find.text('UNVERIFIED'), findsOneWidget);
      expect(find.text('Send Verification Email'), findsOneWidget);
      expect(find.text('Send Password Reset Email'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);

      // Scroll and Tap Sign Out -> Dialog appears
      await tester.ensureVisible(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Logout'), findsOneWidget);

      // Confirm Logout inside dialog
      final confirmSignOutBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Sign Out'),
      );
      await tester.tap(confirmSignOutBtn);
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCalled, isTrue);
    });
  });
}
