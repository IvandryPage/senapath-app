import '../../gamification/domain/rider_progress.dart';

class UserProfile {
  const UserProfile({
    this.displayName = '',
    this.riderStyle = RiderStyle.explorer,
  });

  final String displayName;
  final RiderStyle riderStyle;

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'riderStyle': riderStyle.name,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    displayName: json['displayName'] as String? ?? '',
    riderStyle: RiderStyle.fromName(json['riderStyle']),
  );
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  final String id;
  final String name;
  final String phone;
  final String relationship;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        relationship: json['relationship'] as String,
      );
}
