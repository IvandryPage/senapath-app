import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../profile/domain/user_profile.dart';
import '../../session/domain/ride_session.dart';
import '../data/emergency_contact_actions.dart';

enum EmergencyFlowStatus {
  idle,
  countdown,
  handingOff,
  handedOff,
  cancelled,
  failed,
}

class EmergencyState {
  const EmergencyState({
    this.status = EmergencyFlowStatus.idle,
    this.secondsRemaining = 0,
    this.contactName,
    this.message,
  });

  final EmergencyFlowStatus status;
  final int secondsRemaining;
  final String? contactName;
  final String? message;

  bool get isCountingDown => status == EmergencyFlowStatus.countdown;

  EmergencyState copyWith({
    EmergencyFlowStatus? status,
    int? secondsRemaining,
    String? contactName,
    String? message,
    bool clearMessage = false,
  }) => EmergencyState(
    status: status ?? this.status,
    secondsRemaining: secondsRemaining ?? this.secondsRemaining,
    contactName: contactName ?? this.contactName,
    message: clearMessage ? null : message ?? this.message,
  );
}

class EmergencyCubit extends Cubit<EmergencyState> {
  EmergencyCubit(
    this._actions, {
    this.countdownDuration = const Duration(seconds: 15),
    this.tickInterval = const Duration(seconds: 1),
  }) : super(const EmergencyState());

  final EmergencyContactActions _actions;
  final Duration countdownDuration;
  final Duration tickInterval;
  Timer? _timer;
  EmergencyContact? _countdownContact;
  TelemetryLocation? _countdownLocation;
  int _remainingMilliseconds = 0;

  Future<bool> callContact(EmergencyContact contact) async {
    final opened = await _actions.call(contact);
    _setMessage(
      opened
          ? 'Dialer dibuka. Panggilan belum dimulai.'
          : 'Aplikasi telepon tidak dapat dibuka untuk nomor ini.',
      status: opened
          ? EmergencyFlowStatus.handedOff
          : EmergencyFlowStatus.failed,
      contactName: contact.name,
    );
    return opened;
  }

  Future<bool> openWhatsApp(
    EmergencyContact contact, {
    TelemetryLocation? lastLocation,
  }) => _openSosHandoff(contact, lastLocation);

  void startCountdown({
    required EmergencyContact contact,
    TelemetryLocation? lastLocation,
  }) {
    if (!_isValidContact(contact)) {
      _setMessage(
        'Kontak darurat tidak valid. Periksa nomor di Profil.',
        status: EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return;
    }
    _timer?.cancel();
    _countdownContact = contact;
    _countdownLocation = lastLocation;
    _remainingMilliseconds = countdownDuration.inMilliseconds;
    emit(
      EmergencyState(
        status: EmergencyFlowStatus.countdown,
        secondsRemaining: _secondsRemaining,
        contactName: contact.name,
      ),
    );
    _timer = Timer.periodic(tickInterval, (_) => _tickCountdown());
  }

  void cancelCountdown() {
    if (!state.isCountingDown) return;
    _timer?.cancel();
    _timer = null;
    _countdownContact = null;
    _countdownLocation = null;
    emit(
      const EmergencyState(
        status: EmergencyFlowStatus.cancelled,
        message: 'SOS dibatalkan. Tidak ada pesan yang dibuka.',
      ),
    );
  }

  void clearMessage() => emit(state.copyWith(clearMessage: true));

  void _tickCountdown() {
    _remainingMilliseconds -= tickInterval.inMilliseconds;
    if (_remainingMilliseconds <= 0) {
      _timer?.cancel();
      _timer = null;
      final contact = _countdownContact;
      final location = _countdownLocation;
      _countdownContact = null;
      _countdownLocation = null;
      if (contact == null) return;
      unawaited(_openSosHandoff(contact, location));
      return;
    }
    emit(
      state.copyWith(secondsRemaining: _secondsRemaining, clearMessage: true),
    );
  }

  Future<bool> _openSosHandoff(
    EmergencyContact contact,
    TelemetryLocation? lastLocation,
  ) async {
    if (!_isValidContact(contact)) {
      _setMessage(
        'Kontak darurat tidak valid. Periksa nomor di Profil.',
        status: EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return false;
    }

    emit(
      EmergencyState(
        status: EmergencyFlowStatus.handingOff,
        contactName: contact.name,
      ),
    );
    final message = _buildSosMessage(lastLocation);
    try {
      final opened = await _actions.openWhatsApp(contact, message);
      _setMessage(
        opened
            ? 'WhatsApp dibuka untuk ${contact.name}. Periksa pesan lalu tekan Kirim; pesan belum terkirim.'
            : 'WhatsApp tidak dapat dibuka. Gunakan tombol telepon pada kontak darurat.',
        status: opened
            ? EmergencyFlowStatus.handedOff
            : EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return opened;
    } catch (_) {
      _setMessage(
        'WhatsApp tidak dapat dibuka. Pesan SOS belum terkirim.',
        status: EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return false;
    }
  }

  String _buildSosMessage(TelemetryLocation? location) {
    final locationLine = location == null
        ? 'Lokasi terakhir tidak tersedia.'
        : 'Lokasi terakhir: https://maps.google.com/?q='
              '${location.latitude},${location.longitude}';
    return 'SOS Senapath: Saya mungkin membutuhkan bantuan. $locationLine';
  }

  int get _secondsRemaining =>
      (_remainingMilliseconds / Duration.millisecondsPerSecond).ceil();

  bool _isValidContact(EmergencyContact contact) {
    final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
    return contact.name.trim().isNotEmpty &&
        digits.length >= 7 &&
        digits.length <= 15;
  }

  void _setMessage(
    String message, {
    required EmergencyFlowStatus status,
    required String contactName,
  }) {
    emit(
      EmergencyState(
        status: status,
        message: message,
        contactName: contactName,
      ),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
