import '../../gamification/domain/rider_progress.dart';

class UserProfile {
  /// Membuat profil pengguna dengan nama dan gaya pesepeda bawaan.
  const UserProfile({
    this.displayName = '',
    this.riderStyle = RiderStyle.explorer,
  });

  final String displayName;
  final RiderStyle riderStyle;

  /// Mengubah profil menjadi peta JSON yang dapat disimpan.
  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'riderStyle': riderStyle.name,
  };

  /// Membangun profil dari peta JSON dengan nilai bawaan untuk data kosong.
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    displayName: json['displayName'] as String? ?? '',
    riderStyle: RiderStyle.fromName(json['riderStyle']),
  );
}

class EmergencyContact {
  /// Membuat data kontak darurat lengkap dengan identitas dan hubungan.
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

  /// Mengubah kontak darurat menjadi peta JSON yang dapat disimpan.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };

  /// Membangun kontak darurat dari peta JSON.
  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        relationship: json['relationship'] as String,
      );
}
