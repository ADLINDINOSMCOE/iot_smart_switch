import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// User Profile Model stored in `users/{uid}`:
/// - uid: string
/// - name: string
/// - email: string
/// - profileImage: string?
/// - fcmTokens: list of strings
/// - createdAt: DateTime
/// - updatedAt: DateTime
@immutable
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? profileImage;
  final List<String> fcmTokens;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profileImage,
    this.fcmTokens = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return UserModel.fromMap(snapshot.id, data);
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawTokens = data['fcmTokens'];
    final List<String> tokens = rawTokens is List
        ? rawTokens.whereType<String>().toList()
        : const [];

    return UserModel(
      uid: uid,
      name: data['name'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      profileImage: data['profileImage'] as String?,
      fcmTokens: tokens,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
