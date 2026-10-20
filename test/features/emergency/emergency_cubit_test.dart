import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/emergency/data/emergency_contact_actions.dart';
import 'package:senapath/features/emergency/presentation/emergency_cubit.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

class FakeEmergencyContactActions implements EmergencyContactActions {
  FakeEmergencyContactActions({
    this.callOpens = true,
    this.whatsAppOpens = true,
  });

  bool callOpens;
  bool whatsAppOpens;
  Object? callError;
  Object? whatsAppError;
  final List<String> calls = [];
  final List<String> messages = [];

  @override
  Future<bool> call(EmergencyContact contact) async {
    calls.add(contact.name);
    final failure = callError;
    if (failure != null) throw failure;
    return callOpens;
  }

  @override
  Future<bool> openWhatsApp(EmergencyContact contact, String message) async {
    messages.add(message);
    final failure = whatsAppError;
    if (failure != null) throw failure;
    return whatsAppOpens;
  }
}

EmergencyContact _contact({String name = 'Ibu', String phone = '+6281234567890'}) =>
    EmergencyContact(id: 'c1', name: name, phone: phone, relationship: 'Ibu');

TelemetryLocation _location() => TelemetryLocation(
  recordedAt: DateTime.utc(2026),
  latitude: -6.2,
  longitude: 106.8,
  accuracyMeters: 5,
  altitudeMeters: 10,
  speedMetersPerSecond: 5,
);

void main() {
  group('EmergencyCubit.callContact', () {
    test('reports a successful phone hand-off', () async {
      final actions = FakeEmergencyContactActions();
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      final opened = await cubit.callContact(_contact());
      expect(opened, isTrue);
      expect(cubit.state.status, EmergencyFlowStatus.handedOff);
      expect(cubit.state.message, contains('Aplikasi telepon terbuka'));
      expect(cubit.state.contactName, 'Ibu');
    });

    test('reports a failed phone hand-off', () async {
      final actions = FakeEmergencyContactActions(callOpens: false);
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      final opened = await cubit.callContact(_contact());
      expect(opened, isFalse);
      expect(cubit.state.status, EmergencyFlowStatus.failed);
      expect(cubit.state.message, contains('tidak dapat dibuka'));
    });

    test('handles launcher exceptions', () async {
      final actions = FakeEmergencyContactActions()
        ..callError = StateError('no launcher');
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      final opened = await cubit.callContact(_contact());
      expect(opened, isFalse);
      expect(cubit.state.status, EmergencyFlowStatus.failed);
      expect(cubit.state.message, contains('Coba lagi'));
    });
  });

  group('EmergencyCubit.openWhatsApp', () {
    test('includes the last location in the message', () async {
      final actions = FakeEmergencyContactActions();
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      final opened = await cubit.openWhatsApp(
        _contact(),
        lastLocation: _location(),
      );
      expect(opened, isTrue);
      expect(cubit.state.status, EmergencyFlowStatus.handedOff);
      expect(actions.messages.single, contains('DARURAT'));
      expect(actions.messages.single, contains('maps.google.com'));
      expect(actions.messages.single, contains('-6.200000'));
    });

    test('mentions a missing location', () async {
      final actions = FakeEmergencyContactActions();
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      await cubit.openWhatsApp(_contact());
      expect(actions.messages.single, contains('belum tersedia'));
    });

    test('rejects an invalid contact before handing off', () async {
      final actions = FakeEmergencyContactActions();
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      final opened = await cubit.openWhatsApp(_contact(phone: '123'));
      expect(opened, isFalse);
      expect(cubit.state.status, EmergencyFlowStatus.failed);
      expect(cubit.state.message, contains('tidak valid'));
      expect(actions.messages, isEmpty);
    });

    test('handles launcher failures', () async {
      final actions = FakeEmergencyContactActions()
        ..whatsAppError = StateError('no whatsapp');
      final cubit = EmergencyCubit(actions);
      addTearDown(cubit.close);

      final opened = await cubit.openWhatsApp(_contact());
      expect(opened, isFalse);
      expect(cubit.state.status, EmergencyFlowStatus.failed);
      expect(cubit.state.message, contains('Pesan darurat belum terkirim'));
    });
  });

  group('EmergencyCubit countdown', () {
    test('validates the contact before starting', () {
      final cubit = EmergencyCubit(FakeEmergencyContactActions());
      addTearDown(cubit.close);

      cubit.startCountdown(contact: _contact(phone: '123'));
      expect(cubit.state.status, EmergencyFlowStatus.failed);
      expect(cubit.state.isCountingDown, isFalse);
    });

    test('counts down and hands off to WhatsApp at zero', () async {
      final actions = FakeEmergencyContactActions();
      final cubit = EmergencyCubit(
        actions,
        countdownDuration: const Duration(milliseconds: 100),
        tickInterval: const Duration(milliseconds: 40),
      );
      addTearDown(cubit.close);

      cubit.startCountdown(contact: _contact(), lastLocation: _location());
      expect(cubit.state.status, EmergencyFlowStatus.countdown);
      expect(cubit.state.secondsRemaining, 1);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(actions.messages, hasLength(1));
      expect(
        cubit.state.status,
        anyOf(EmergencyFlowStatus.handedOff, EmergencyFlowStatus.handingOff),
      );
    });

    test('cancelCountdown stops the timer', () async {
      final actions = FakeEmergencyContactActions();
      final cubit = EmergencyCubit(
        actions,
        countdownDuration: const Duration(seconds: 5),
        tickInterval: const Duration(milliseconds: 30),
      );
      addTearDown(cubit.close);

      cubit.startCountdown(contact: _contact());
      cubit.cancelCountdown();
      expect(cubit.state.status, EmergencyFlowStatus.cancelled);
      expect(cubit.state.message, contains('dibatalkan'));

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(actions.messages, isEmpty);
    });

    test('cancelCountdown outside a countdown is a no-op', () {
      final cubit = EmergencyCubit(FakeEmergencyContactActions());
      addTearDown(cubit.close);
      cubit.cancelCountdown();
      expect(cubit.state.status, EmergencyFlowStatus.idle);
    });
  });

  test('clearMessage empties the message', () async {
    final cubit = EmergencyCubit(FakeEmergencyContactActions());
    addTearDown(cubit.close);
    await cubit.callContact(_contact());
    expect(cubit.state.message, isNotNull);
    cubit.clearMessage();
    expect(cubit.state.message, isNull);
  });
}
