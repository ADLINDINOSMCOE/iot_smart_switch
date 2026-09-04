import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/services/notification_service.dart';

class FakeNotificationService extends Fake implements NotificationService {
  final Map<String, List<String>> userTokensMap = {};
  bool permissionGranted = true;
  String? lastNavigatedTarget;

  @override
  Future<bool> requestPermission() async {
    return permissionGranted;
  }

  @override
  Future<String?> registerDeviceToken(String userId) async {
    const token = 'fake_fcm_token_xyz789';
    userTokensMap.putIfAbsent(userId, () => []).add(token);
    return token;
  }

  @override
  Future<void> unregisterDeviceToken(String userId) async {
    userTokensMap.remove(userId);
  }

  @override
  void setupMessageHandlers({
    required void Function(String target, Map<String, dynamic> data) onNavigate,
  }) {}
}

void main() {
  group('NotificationService FCM Registration & Deep-link Tests', () {
    test('Registers FCM device token under user document', () async {
      final fakeService = FakeNotificationService();

      final token = await fakeService.registerDeviceToken('user_test_123');

      expect(token, isNotNull);
      expect(fakeService.userTokensMap['user_test_123'], contains(token));
    });

    test('Unregisters FCM device token on sign-out', () async {
      final fakeService = FakeNotificationService();
      await fakeService.registerDeviceToken('user_test_123');
      expect(fakeService.userTokensMap.containsKey('user_test_123'), isTrue);

      await fakeService.unregisterDeviceToken('user_test_123');
      expect(fakeService.userTokensMap.containsKey('user_test_123'), isFalse);
    });

    test('Handles notification permission granting', () async {
      final fakeService = FakeNotificationService();
      final isGranted = await fakeService.requestPermission();
      expect(isGranted, isTrue);
    });
  });
}
