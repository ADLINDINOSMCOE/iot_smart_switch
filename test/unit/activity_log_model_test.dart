import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/activity_log_model.dart';

void main() {
  group('ActivityLogModel Unit Tests', () {
    test('Serializes and deserializes activity log map correctly', () {
      final now = DateTime.now();
      final log = ActivityLogModel(
        id: 'log_001',
        switchId: 'switch_1',
        switchName: 'Living Room Light',
        deviceId: 'esp32_001',
        userId: 'user_123',
        userEmail: 'user@example.com',
        action: 'ON',
        source: 'mobile_app',
        timestamp: now,
      );

      final map = log.toMap();
      expect(map['switchId'], 'switch_1');
      expect(map['switchName'], 'Living Room Light');
      expect(map['deviceId'], 'esp32_001');
      expect(map['userId'], 'user_123');
      expect(map['userEmail'], 'user@example.com');
      expect(map['action'], 'ON');
      expect(map['source'], 'mobile_app');

      final deserialized = ActivityLogModel.fromMap('log_001', map);
      expect(deserialized.id, 'log_001');
      expect(deserialized.switchId, 'switch_1');
      expect(deserialized.action, 'ON');
      expect(deserialized.userId, 'user_123');
    });
  });
}
