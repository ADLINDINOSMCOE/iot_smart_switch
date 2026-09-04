import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _customFirestore = firestore,
        _customMessaging = messaging;

  final FirebaseFirestore? _customFirestore;
  final FirebaseMessaging? _customMessaging;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseMessaging get _messaging =>
      _customMessaging ?? FirebaseMessaging.instance;

  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService();

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection('users');

  /// Requests user permission for push notifications (iOS / Android 13+)
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      developer.log(
        'Notification permission status: ${settings.authorizationStatus}',
        name: 'NotificationService',
      );
      return isAuthorized;
    } catch (e) {
      developer.log('Error requesting notification permission: $e',
          name: 'NotificationService');
      return false;
    }
  }

  /// Obtains current FCM token and registers it to users/{userId}
  Future<String?> registerDeviceToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        developer.log('No FCM token obtained.', name: 'NotificationService');
        return null;
      }

      developer.log('Obtained FCM token: $token for user: $userId',
          name: 'NotificationService');

      await usersCollection.doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log('Registered FCM token to users/$userId',
          name: 'NotificationService');
      return token;
    } catch (e) {
      developer.log('Failed to register FCM token: $e',
          name: 'NotificationService');
      return null;
    }
  }

  /// Removes FCM token upon sign-out
  Future<void> unregisterDeviceToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await usersCollection.doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        developer.log('Unregistered FCM token from users/$userId',
            name: 'NotificationService');
      }
    } catch (e) {
      developer.log('Failed to unregister FCM token: $e',
          name: 'NotificationService');
    }
  }

  /// Configures deep-link and action handlers for incoming notifications
  void setupMessageHandlers({
    required void Function(String target, Map<String, dynamic> data) onNavigate,
  }) {
    // 1. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log(
        'Received foreground message: ${message.notification?.title} - ${message.notification?.body}',
        name: 'NotificationService',
      );
    });

    // 2. Background tap / opened app handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log(
        'App opened from notification: ${message.data}',
        name: 'NotificationService',
      );
      _handleDeepLink(message.data, onNavigate);
    });

    // 3. Cold launch initial message handler
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        developer.log(
          'App launched cold from notification: ${message.data}',
          name: 'NotificationService',
        );
        _handleDeepLink(message.data, onNavigate);
      }
    });
  }

  void _handleDeepLink(
    Map<String, dynamic> data,
    void Function(String target, Map<String, dynamic> data) onNavigate,
  ) {
    final target = (data['target'] as String? ?? 'home').toLowerCase();
    onNavigate(target, data);
  }
}
