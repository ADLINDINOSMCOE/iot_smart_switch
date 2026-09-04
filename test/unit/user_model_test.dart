import 'package:flutter_test/flutter_test.dart';
import 'package:iot_smart_switch/models/user_model.dart';

void main() {
  group('UserModel Unit Tests', () {
    test('Serializes and deserializes UserModel correctly without passwords or tokens', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_abc',
        name: 'Jane Doe',
        email: 'jane@example.com',
        fcmTokens: ['token_1', 'token_2'],
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toMap();
      expect(map['name'], 'Jane Doe');
      expect(map['email'], 'jane@example.com');
      expect(map['fcmTokens'], ['token_1', 'token_2']);
      expect(map.containsKey('password'), isFalse);

      final deserialized = UserModel.fromMap('user_abc', map);
      expect(deserialized.uid, 'user_abc');
      expect(deserialized.name, 'Jane Doe');
      expect(deserialized.email, 'jane@example.com');
      expect(deserialized.fcmTokens.length, 2);
    });
  });
}
