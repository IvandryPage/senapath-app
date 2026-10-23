import 'package:url_launcher/url_launcher.dart';

import '../../profile/domain/user_profile.dart';

abstract interface class EmergencyContactActions {
  /// Membuka panggilan telepon ke kontak dan mengembalikan status berhasil.
  Future<bool> call(EmergencyContact contact);
  /// Membuka WhatsApp ke kontak dengan pesan tertentu.
  Future<bool> openWhatsApp(EmergencyContact contact, String message);
}

class UrlLauncherEmergencyContactActions implements EmergencyContactActions {
  /// Membuat aksi kontak berbasis url_launcher.
  const UrlLauncherEmergencyContactActions();

  @override
  /// Meluncurkan aplikasi telepon setelah nomor divalidasi.
  Future<bool> call(EmergencyContact contact) async {
    final phone = _validatedPhone(contact.phone);
    if (phone == null) return false;
    return launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  /// Membuka tautan wa.me dengan nomor ternormalisasi dan pesan darurat.
  Future<bool> openWhatsApp(EmergencyContact contact, String message) async {
    final phone = normalizeWhatsAppPhone(contact.phone);
    if (phone == null) return false;
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Memvalidasi dan membersihkan nomor telepon, atau null bila tidak valid.
  String? _validatedPhone(String phone) {
    final trimmed = phone.trim();
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(trimmed)) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return null;
    return trimmed.replaceAll(RegExp(r'[ ()-]'), '');
  }
}

/// Menormalkan nomor WhatsApp berawalan plus menjadi digit saja.
String? normalizeWhatsAppPhone(String phone) {
  final trimmed = phone.trim();
  if (!RegExp(r'^\+[0-9 ()-]+$').hasMatch(trimmed)) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) return null;
  return digits;
}
