import 'package:url_launcher/url_launcher.dart';

import '../../profile/domain/user_profile.dart';

abstract interface class EmergencyContactActions {
  Future<bool> call(EmergencyContact contact);
  Future<bool> openWhatsApp(EmergencyContact contact, String message);
}

class UrlLauncherEmergencyContactActions implements EmergencyContactActions {
  const UrlLauncherEmergencyContactActions();

  @override
  Future<bool> call(EmergencyContact contact) async {
    final phone = _validatedPhone(contact.phone);
    if (phone == null) return false;
    return launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<bool> openWhatsApp(EmergencyContact contact, String message) async {
    final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return false;
    final uri = Uri.https('wa.me', '/$digits', {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _validatedPhone(String phone) {
    final trimmed = phone.trim();
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(trimmed)) return null;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return null;
    return trimmed.replaceAll(RegExp(r'[ ()-]'), '');
  }
}
