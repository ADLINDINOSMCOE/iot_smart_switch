import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  bool _permissionGranted = false;
  
  bool get isInitialized => _initialized;
  bool get isPermissionGranted => _permissionGranted;

  // Notification preferences keys
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _deviceStateNotificationsKey = 'device_state_notifications';
  static const String _scheduleNotificationsKey = 'schedule_notifications';
  static const String _energyAlertsKey = 'energy_alerts';

  // =========================================================
  // INITIALIZE NOTIFICATION SERVICE
  // =========================================================
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      _permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized;

      if (kDebugMode) {
        debugPrint('Notification permission granted: $_permissionGranted');
      }

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(initializationSettings);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      // Get FCM token
      final token = await _messaging.getToken();
      if (kDebugMode && token != null) {
        debugPrint('FCM Token: $token');
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // =========================================================
  // HANDLE FOREGROUND MESSAGES
  // =========================================================
  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'iot_switch_channel',
            'IoT Switch Notifications',
            channelDescription: 'Notifications for IoT Switch devices',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }

  // =========================================================
  // HANDLE MESSAGE OPENED
  // =========================================================
  void _handleMessageOpened(RemoteMessage message) {
    // Handle notification tap
    if (kDebugMode) {
      print('Notification opened: ${message.messageId}');
    }
  }

  // =========================================================
  // GET FCM TOKEN
  // =========================================================
  Future<String?> getFCMToken() async {
    return await _messaging.getToken();
  }

  // =========================================================
  // SUBSCRIBE TO DEVICE TOPIC
  // =========================================================
  Future<void> subscribeToDevice(String deviceId) async {
    try {
      await _messaging.subscribeToTopic('device_$deviceId');
      if (kDebugMode) {
        print('Subscribed to device_$deviceId');
      }
    } catch (e) {
      debugPrint('Error subscribing to device topic: $e');
    }
  }

  // =========================================================
  // UNSUBSCRIBE FROM DEVICE TOPIC
  // =========================================================
  Future<void> unsubscribeFromDevice(String deviceId) async {
    try {
      await _messaging.unsubscribeFromTopic('device_$deviceId');
      if (kDebugMode) {
        print('Unsubscribed from device_$deviceId');
      }
    } catch (e) {
      debugPrint('Error unsubscribing from device topic: $e');
    }
  }

  // =========================================================
  // NOTIFICATION PREFERENCES
  // =========================================================
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  Future<bool> areDeviceStateNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deviceStateNotificationsKey) ?? true;
  }

  Future<void> setDeviceStateNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceStateNotificationsKey, enabled);
  }

  Future<bool> areScheduleNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduleNotificationsKey) ?? true;
  }

  Future<void> setScheduleNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduleNotificationsKey, enabled);
  }

  Future<bool> areEnergyAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_energyAlertsKey) ?? true;
  }

  Future<void> setEnergyAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_energyAlertsKey, enabled);
  }

  // =========================================================
  // REQUEST PERMISSION AGAIN
  // =========================================================
  Future<bool> requestPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
      return _permissionGranted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }
}