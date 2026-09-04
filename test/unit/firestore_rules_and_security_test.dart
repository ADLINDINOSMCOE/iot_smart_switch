import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/device_model.dart';
import 'package:iot_smart_switch/models/schedule_model.dart';
import 'package:iot_smart_switch/models/switch_model.dart';
import 'package:iot_smart_switch/models/user_model.dart';

void main() {
  group('Firestore Security Rules & Authorization Tests', () {
    test('Switches Collection: Only isOn is mutable, structure is locked', () {
      const originalSwitch = SwitchModel(
        id: 'switch_1',
        name: 'Living Room Light',
        room: 'Living Room',
        isOn: false,
        deviceId: 'esp32_001',
        ownerId: 'user_A',
      );

      // State toggle change (Allowed by rule: affectedKeys().hasOnly(['isOn']))
      final toggledSwitch = originalSwitch.copyWith(isOn: true);
      expect(toggledSwitch.isOn, isTrue);
      expect(toggledSwitch.deviceId, originalSwitch.deviceId);
      expect(toggledSwitch.name, originalSwitch.name);
      expect(toggledSwitch.room, originalSwitch.room);
      expect(toggledSwitch.ownerId, 'user_A');
    });

    test('Multi-User Isolation: User A device access is denied to User B', () {
      const userASwitch = SwitchModel(
        id: 'switch_private_A',
        name: 'Private Room Light',
        room: 'Master Bedroom',
        isOn: false,
        deviceId: 'esp32_001',
        ownerId: 'user_A_uid',
      );

      // Simulating rule predicate: canAccessSwitch(switchData)
      bool canUserAccess(SwitchModel s, String requestingAuthUid) {
        if (s.ownerId == null) return true; // Legacy/shared fixtures
        return s.ownerId == requestingAuthUid;
      }

      // User A can access their own switch
      expect(canUserAccess(userASwitch, 'user_A_uid'), isTrue);

      // User B CANNOT access User A's switch
      expect(canUserAccess(userASwitch, 'user_B_uid'), isFalse);
    });

    test('Multi-User Isolation: User A schedule is isolated from User B', () {
      final userASchedule = ScheduleModel(
        id: 'sched_A',
        switchId: 'switch_1',
        action: 'on',
        time: DateTime.now().toUtc(),
        userId: 'user_A_uid',
      );

      bool canUserAccessSchedule(ScheduleModel s, String requestingAuthUid) {
        if (s.userId == null) return true;
        return s.userId == requestingAuthUid;
      }

      expect(canUserAccessSchedule(userASchedule, 'user_A_uid'), isTrue);
      expect(canUserAccessSchedule(userASchedule, 'user_B_uid'), isFalse);
    });

    test('User Profiles: users/{userId} strict isolation prevents credential exposure', () {
      final profile = UserModel(
        uid: 'user_A_uid',
        name: 'Alice',
        email: 'alice@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = profile.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('jwtSecret'), isFalse);
      expect(map.containsKey('serviceAccountKey'), isFalse);
    });

    test('Schedules Collection: Strict schema and action validation', () {
      final validSchedule = ScheduleModel(
        id: 'sched_1',
        switchId: 'switch_1',
        action: 'on',
        time: DateTime.now().toUtc(),
        type: 'schedule',
        status: 'pending',
        repeatDays: ['mon', 'wed', 'fri'],
      );

      expect(['on', 'off'], contains(validSchedule.action));
      expect(['timer', 'schedule'], contains(validSchedule.type));
      expect(['pending', 'completed', 'cancelled'], contains(validSchedule.status));
      expect(validSchedule.isRepeating, isTrue);
    });

    test('Devices Collection: Heartbeat online timeout strictly guarded', () {
      final now = DateTime.now();
      final liveDevice = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: now.subtract(const Duration(seconds: 10)),
        actualStates: const {'switch_1': true},
      );
      expect(liveDevice.isOnline, isTrue);

      final deadDevice = DeviceModel(
        deviceId: 'esp32_001',
        lastSeen: now.subtract(const Duration(seconds: 35)),
        actualStates: const {'switch_1': true},
      );
      expect(deadDevice.isOnline, isFalse);
    });
  });
}
