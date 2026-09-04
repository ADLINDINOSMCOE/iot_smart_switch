import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/device_model.dart';

void main() {
  group('DeviceModel Telemetry & Online Calculation Tests', () {
    test('Calculates isOnline = true when lastSeen is within 25 seconds', () {
      final recentSeen = DateTime.now().subtract(const Duration(seconds: 10));
      final device = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: recentSeen,
        actualStates: const {'switch_1': true},
      );

      expect(device.isOnline, isTrue);
    });

    test('Calculates isOnline = false when lastSeen exceeds 25-second threshold', () {
      final staleSeen = DateTime.now().subtract(const Duration(seconds: 30));
      final device = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: staleSeen,
        actualStates: const {'switch_1': true},
      );

      expect(device.isOnline, isFalse);
    });

    test('Verifies physical relay state synchronization correctly', () {
      final device = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: DateTime.now(),
        actualStates: const {
          'switch_1': true,
          'switch_2': false,
        },
      );

      // switch_1: actual is ON, requested is ON -> Synced
      expect(device.isSwitchSynced('switch_1', true), isTrue);

      // switch_1: actual is ON, requested is OFF -> Unsynced
      expect(device.isSwitchSynced('switch_1', false), isFalse);

      // switch_3: not reported -> Unsynced
      expect(device.isSwitchSynced('switch_3', true), isFalse);
    });

    test('Serializes toMap() and deserializes fromMap() accurately', () {
      final now = DateTime.now();
      final data = {
        'lastSeen': Timestamp.fromDate(now),
        'actualStates': {'switch_1': true, 'switch_2': false},
      };

      final device = DeviceModel.fromMap('esp32_001', data);

      expect(device.deviceId, 'esp32_001');
      expect(device.actualStates['switch_1'], isTrue);
      expect(device.actualStates['switch_2'], isFalse);

      final map = device.toMap();
      expect(map.containsKey('lastSeen'), isTrue);
      expect(map['actualStates'], equals({'switch_1': true, 'switch_2': false}));
    });
  });
}
