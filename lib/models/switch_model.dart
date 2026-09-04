import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Authoritative Switch Model:
/// - id: string (document ID)
/// - name: string (e.g., "Living Room Light")
/// - room: string (e.g., "Living Room")
/// - isOn: boolean
/// - deviceId: string (e.g., "esp32_001")
/// - ownerId: string? (user UID for multi-tenant device ownership)
@immutable
class SwitchModel {
  final String id;
  final String name;
  final String room;
  final bool isOn;
  final String deviceId;
  final String? ownerId;

  const SwitchModel({
    required this.id,
    required this.name,
    required this.room,
    required this.isOn,
    required this.deviceId,
    this.ownerId,
  });

  /// Factory constructor to deserialize Firestore DocumentSnapshot
  factory SwitchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return SwitchModel.fromMap(snapshot.id, data);
  }

  /// Factory constructor to deserialize a Map payload with document ID
  factory SwitchModel.fromMap(String id, Map<String, dynamic> data) {
    return SwitchModel(
      id: id,
      name: data['name'] as String? ?? 'Unnamed Switch',
      room: data['room'] as String? ?? 'Unassigned Room',
      isOn: data['isOn'] as bool? ?? false,
      deviceId: data['deviceId'] as String? ?? 'unassigned',
      ownerId: data['ownerId'] as String?,
    );
  }

  /// Serializes model strictly to Firestore schema fields
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'room': room,
      'isOn': isOn,
      'deviceId': deviceId,
    };
    if (ownerId != null) {
      map['ownerId'] = ownerId;
    }
    return map;
  }

  /// Creates a copy with optionally updated fields
  SwitchModel copyWith({
    String? id,
    String? name,
    String? room,
    bool? isOn,
    String? deviceId,
    String? ownerId,
  }) {
    return SwitchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      room: room ?? this.room,
      isOn: isOn ?? this.isOn,
      deviceId: deviceId ?? this.deviceId,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SwitchModel &&
        other.id == id &&
        other.name == name &&
        other.room == room &&
        other.isOn == isOn &&
        other.deviceId == deviceId &&
        other.ownerId == ownerId;
  }

  @override
  int get hashCode => Object.hash(id, name, room, isOn, deviceId, ownerId);

  @override
  String toString() {
    return 'SwitchModel(id: $id, name: $name, room: $room, isOn: $isOn, deviceId: $deviceId, ownerId: $ownerId)';
  }
}
