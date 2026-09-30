class UserProfile {
  const UserProfile({this.displayName = '', this.teamName = ''});

  final String displayName;
  final String teamName;

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'teamName': teamName,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    displayName: json['displayName'] as String? ?? '',
    teamName: json['teamName'] as String? ?? '',
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
