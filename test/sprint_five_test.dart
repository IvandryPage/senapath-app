import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/emergency/data/emergency_contact_actions.dart';
import 'package:senapath/features/emergency/presentation/emergency_cubit.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

void main() {
  test('cancelling SOS countdown prevents WhatsApp handoff', () async {
    final actions = _FakeEmergencyActions();
    final cubit = EmergencyCubit(
      actions,
      countdownDuration: const Duration(seconds: 2),
      tickInterval: const Duration(milliseconds: 10),
    );
    const contact = EmergencyContact(
      id: 'contact-1',
      name: 'Tim Support',
      phone: '+628123456789',
      relationship: 'Tim',
    );

    cubit.startCountdown(contact: contact);
    expect(cubit.state.isCountingDown, isTrue);
    cubit.cancelCountdown();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(cubit.state.status, EmergencyFlowStatus.cancelled);
    expect(actions.whatsappMessages, isEmpty);
    await cubit.close();
  });

  test('completed SOS countdown opens WhatsApp with last location', () async {
    final actions = _FakeEmergencyActions();
    final cubit = EmergencyCubit(
      actions,
      countdownDuration: const Duration(milliseconds: 20),
      tickInterval: const Duration(milliseconds: 10),
    );
    const contact = EmergencyContact(
      id: 'contact-1',
      name: 'Tim Support',
      phone: '+628123456789',
      relationship: 'Tim',
    );
    final location = TelemetryLocation(
      recordedAt: DateTime.utc(2026, 10, 1),
      latitude: -6.2,
      longitude: 106.8,
      accuracyMeters: 5,
      altitudeMeters: 10,
      speedMetersPerSecond: 0,
    );

    cubit.startCountdown(contact: contact, lastLocation: location);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(actions.whatsappMessages, hasLength(1));
    expect(actions.whatsappMessages.single, contains('maps.google.com'));
    expect(cubit.state.status, EmergencyFlowStatus.handedOff);
    expect(cubit.state.message, contains('belum terkirim'));
    await cubit.close();
  });
}

class _FakeEmergencyActions implements EmergencyContactActions {
  final List<String> whatsappMessages = [];

  @override
  Future<bool> call(EmergencyContact contact) async => true;

  @override
  Future<bool> openWhatsApp(EmergencyContact contact, String message) async {
    whatsappMessages.add(message);
    return true;
  }
}
