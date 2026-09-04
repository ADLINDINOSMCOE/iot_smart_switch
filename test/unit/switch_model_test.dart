import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/services/switch_service.dart';

void main() {
  group('SwitchModel Schema and Integrity Tests', () {
    test('Correctly serializes toMap() matching authoritative Firestore schema', () {
      const switchModel = SwitchModel(
        id: 'switch_1',
        name: 'Living Room Main Light',
        room: 'Living Room',
        isOn: true,
        deviceId: 'esp32_001',
      );

      final map = switchModel.toMap();

      // Ensure exact keys according to spec (no extra/missing fields)
      expect(map.keys.toSet(), equals({'name', 'room', 'isOn', 'deviceId'}));
      expect(map['name'], 'Living Room Main Light');
      expect(map['room'], 'Living Room');
      expect(map['isOn'], true);
      expect(map['deviceId'], 'esp32_001');
    });

    test('Correctly deserializes fromMap()', () {
      final data = {
        'name': 'Ceiling Fan',
        'room': 'Bedroom',
        'isOn': false,
        'deviceId': 'esp32_002',
      };

      final switchModel = SwitchModel.fromMap('switch_2', data);

      expect(switchModel.id, 'switch_2');
      expect(switchModel.name, 'Ceiling Fan');
      expect(switchModel.room, 'Bedroom');
      expect(switchModel.isOn, false);
      expect(switchModel.deviceId, 'esp32_002');
    });

    test('Falls back safely when optional keys are absent', () {
      final switchModel = SwitchModel.fromMap('switch_x', {});

      expect(switchModel.id, 'switch_x');
      expect(switchModel.name, 'Unnamed Switch');
      expect(switchModel.room, 'Unassigned Room');
      expect(switchModel.isOn, false);
      expect(switchModel.deviceId, 'unassigned');
    });

    test('Supports immutable copyWith modifications', () {
      const original = SwitchModel(
        id: 'switch_1',
        name: 'Living Room Light',
        room: 'Living Room',
        isOn: false,
        deviceId: 'esp32_001',
      );

      final modified = original.copyWith(isOn: true);

      expect(modified.isOn, true);
      expect(modified.id, original.id);
      expect(modified.name, original.name);
      expect(modified.room, original.room);
      expect(modified.deviceId, original.deviceId);
      expect(original.isOn, false); // Immutability preserved
    });

    test('Verifies equality and hashCode consistency', () {
      const switchA = SwitchModel(
        id: 'switch_1',
        name: 'Light',
        room: 'Hall',
        isOn: true,
        deviceId: 'esp32_001',
      );
      const switchB = SwitchModel(
        id: 'switch_1',
        name: 'Light',
        room: 'Hall',
        isOn: true,
        deviceId: 'esp32_001',
      );

      expect(switchA, equals(switchB));
      expect(switchA.hashCode, equals(switchB.hashCode));
    });

    test('Verifies 4 authoritative sample switch seed definitions', () {
      final samples = SwitchService.sampleSwitches;

      expect(samples.length, 4);
      expect(samples[0].id, 'switch_1');
      expect(samples[0].deviceId, 'esp32_001');
      expect(samples[1].id, 'switch_2');
      expect(samples[2].id, 'switch_3');
      expect(samples[3].id, 'switch_4');
      expect(samples[3].deviceId, 'esp32_002');
    });
  });
}
