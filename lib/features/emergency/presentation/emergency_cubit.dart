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
  /// Membuat keadaan awal alur darurat dengan status idle.
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

  /// Menandakan hitung mundur SOS sedang berjalan.
  bool get isCountingDown => status == EmergencyFlowStatus.countdown;

  /// Menyalin keadaan dengan perubahan opsional dan opsi hapus pesan.
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
  /// Membuat cubit darurat dengan aksi kontak dan durasi hitung mundur.
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

  /// Membuka panggilan ke kontak darurat dan memperbarui status alur.
  Future<bool> callContact(EmergencyContact contact) async {
    try {
      final opened = await _actions.call(contact);
      _setMessage(
        opened
            ? 'Aplikasi telepon terbuka untuk ${contact.name}. Tekan Panggil untuk menelepon.'
            : 'Aplikasi telepon tidak dapat dibuka untuk nomor ini.',
        status: opened
            ? EmergencyFlowStatus.handedOff
            : EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return opened;
    } catch (_) {
      _setMessage(
        'Aplikasi telepon tidak dapat dibuka. Coba lagi atau gunakan WhatsApp.',
        status: EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return false;
    }
  }

  /// Membuka WhatsApp dengan pesan SOS berisi lokasi terakhir.
  Future<bool> openWhatsApp(
    EmergencyContact contact, {
    TelemetryLocation? lastLocation,
  }) => _openSosHandoff(contact, lastLocation);

  /// Memvalidasi kontak lalu memulai hitung mundur sebelum SOS dikirim.
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

  /// Membatalkan hitung mundur dan menandai alur SOS dibatalkan.
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

  /// Menghapus pesan status dari keadaan.
  void clearMessage() => emit(state.copyWith(clearMessage: true));

  /// Mengurangi sisa waktu dan memicu pengiriman SOS saat hitung mundur habis.
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

  /// Memvalidasi kontak, menyusun pesan SOS, lalu membuka WhatsApp.
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
            ? 'WhatsApp terbuka untuk ${contact.name}. Periksa pesan dan lokasi, lalu tekan Kirim.'
            : 'WhatsApp tidak dapat dibuka. Gunakan tombol telepon pada kontak darurat.',
        status: opened
            ? EmergencyFlowStatus.handedOff
            : EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return opened;
    } catch (_) {
      _setMessage(
        'WhatsApp tidak dapat dibuka. Pesan darurat belum terkirim.',
        status: EmergencyFlowStatus.failed,
        contactName: contact.name,
      );
      return false;
    }
  }

  /// Menyusun teks pesan darurat lengkap dengan tautan lokasi bila tersedia.
  String _buildSosMessage(TelemetryLocation? location) {
    final locationText = location == null
        ? 'Lokasi terakhir saya belum tersedia.'
        : 'Lokasi terakhir saya: https://maps.google.com/?q='
              '${location.latitude.toStringAsFixed(6)},'
              '${location.longitude.toStringAsFixed(6)}';
    return [
      'DARURAT: Saya mengalami keadaan darurat saat bersepeda dan membutuhkan pertolongan.',
      locationText,
      'Tolong hubungi saya secepatnya atau kirim bantuan ke lokasi ini.',
    ].join('\n');
  }

  /// Menghitung sisa detik hitung mundur dengan pembulatan ke atas.
  int get _secondsRemaining =>
      (_remainingMilliseconds / Duration.millisecondsPerSecond).ceil();

  /// Memeriksa nama terisi dan panjang nomor telepon dalam rentang wajar.
  bool _isValidContact(EmergencyContact contact) {
    final digits = contact.phone.replaceAll(RegExp(r'\D'), '');
    return contact.name.trim().isNotEmpty &&
        digits.length >= 7 &&
        digits.length <= 15;
  }

  /// Menerbitkan keadaan baru berisi pesan, status, dan nama kontak.
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
  /// Menghentikan timer yang aktif sebelum menutup cubit.
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
