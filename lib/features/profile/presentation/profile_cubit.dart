import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/validation/validators.dart';
import '../data/user_profile_repository.dart';
import '../domain/user_profile.dart';

class ProfileState {
  /// Membuat keadaan awal profil dengan data kosong dan status belum dimuat.
  const ProfileState({
    this.profile = const UserProfile(),
    this.contacts = const [],
    this.avatarBytes,
    this.isLoaded = false,
    this.isSaving = false,
    this.message,
  });

  final UserProfile profile;
  final List<EmergencyContact> contacts;
  final Uint8List? avatarBytes;
  final bool isLoaded;
  final bool isSaving;
  final String? message;

  /// Menyalin keadaan dengan perubahan opsional, termasuk penghapusan avatar/pesan.
  ProfileState copyWith({
    UserProfile? profile,
    List<EmergencyContact>? contacts,
    Uint8List? avatarBytes,
    bool clearAvatar = false,
    bool? isLoaded,
    bool? isSaving,
    String? message,
    bool clearMessage = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      contacts: contacts ?? this.contacts,
      avatarBytes: clearAvatar ? null : avatarBytes ?? this.avatarBytes,
      isLoaded: isLoaded ?? this.isLoaded,
      isSaving: isSaving ?? this.isSaving,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class ProfileCubit extends Cubit<ProfileState> {
  /// Membuat cubit profil dengan repositori penyimpanan yang diberikan.
  ProfileCubit(this._repository) : super(const ProfileState());

  static const maximumContacts = 3;
  final UserProfileRepository _repository;
  int _loadGeneration = 0;
  /// Mengembalikan repositori cloud bila didukung, atau null.
  CloudUserProfileRepository? get _cloudRepository {
    if (_repository is! CloudUserProfileRepository) return null;
    return _repository as CloudUserProfileRepository;
  }

  /// Mengembalikan repositori kontak cloud bila didukung, atau null.
  CloudContactsRepository? get _cloudContactsRepository {
    if (_repository is! CloudContactsRepository) return null;
    return _repository as CloudContactsRepository;
  }

  /// Mengatur ulang status muat lalu memuat profil kembali dari sumbernya.
  Future<void> reloadProfile() async {
    emit(state.copyWith(isLoaded: false, clearMessage: true));
    await load();
  }

  /// Memuat profil, kontak, avatar, dan menyinkronkannya dengan cloud.
  Future<void> load() async {
    if (state.isLoaded) return;
    final generation = ++_loadGeneration;
    try {
      var profile = await _repository.loadProfile();
      var contacts = await _repository.loadContacts();
      Uint8List? avatar;
      String? message;
      try {
        avatar = await _repository.loadAvatar();
      } catch (_) {
        message = 'Foto profil tidak dapat dibuka.';
      }

      final cloudContactsRepository = _cloudContactsRepository;
      if (cloudContactsRepository != null &&
          _cloudRepository?.isCloudSignedIn == true) {
        try {
          final cloudContacts = await cloudContactsRepository
              .loadCloudContacts();
          if (cloudContacts != null && cloudContacts.isNotEmpty) {
            contacts = cloudContacts;
            await _repository.saveContacts(cloudContacts);
          } else if (contacts.isNotEmpty) {
            await cloudContactsRepository.saveCloudContacts(contacts);
          }
        } on CloudProfileSyncException {
          message = 'Kontak darurat di ponsel ditampilkan, tetapi belum diperbarui di akun online.';
        }
      }

      final cloudRepository = _cloudRepository;
      if (cloudRepository?.isCloudSignedIn == true) {
        try {
          final cloudProfile = await cloudRepository!.loadCloudProfile();
          if (cloudProfile != null) {
            profile = UserProfile(
              displayName: cloudProfile.displayName.isNotEmpty
                  ? cloudProfile.displayName
                  : profile.displayName,
              riderStyle: cloudProfile.riderStyle,
            );
            if (cloudProfile.displayName.isNotEmpty) {
              await _repository.saveProfile(profile);
            } else if (profile.displayName.trim().isNotEmpty) {
              await cloudRepository.saveCloudProfile(profile);
            }
          } else if (profile.displayName.trim().isNotEmpty) {
            await cloudRepository.saveCloudProfile(profile);
          }
        } on CloudProfileSyncException {
          message = 'Profil di ponsel ditampilkan, tetapi belum diperbarui di akun online.';
        }
      }

      if (isClosed || generation != _loadGeneration) return;
      emit(
        ProfileState(
          profile: profile,
          contacts: contacts,
          avatarBytes: avatar,
          isLoaded: true,
          message: message,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          isLoaded: true,
          message: 'Data profil di ponsel tidak dapat dibuka.',
        ),
      );
    }
  }

  /// Memvalidasi lalu menyimpan profil lokal dan cloud, mengembalikan keberhasilan.
  Future<bool> saveProfile(UserProfile profile) async {
    final cleanedName = TextValidators.sanitizeSingleLine(profile.displayName);
    if (cleanedName.isEmpty) {
      emit(state.copyWith(message: 'Nama tidak boleh kosong.'));
      return false;
    }
    if (cleanedName.runes.length > InputLimits.displayNameMaxLength) {
      emit(
        state.copyWith(
          message:
              'Nama maksimal ${InputLimits.displayNameMaxLength} karakter.',
        ),
      );
      return false;
    }

    final updated = UserProfile(
      displayName: cleanedName,
      riderStyle: profile.riderStyle,
    );
    emit(state.copyWith(isSaving: true, clearMessage: true));
    try {
      await _repository.saveProfile(updated);
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          message: 'Profil tidak dapat disimpan di perangkat.',
        ),
      );
      return false;
    }
    final cloudRepository = _cloudRepository;
    final shouldSyncCloud = cloudRepository?.isCloudSignedIn == true;
    emit(state.copyWith(profile: updated, isSaving: shouldSyncCloud));
    if (shouldSyncCloud) {
      try {
        await cloudRepository!.saveCloudProfile(updated);
        emit(
          state.copyWith(
            profile: updated,
            isSaving: false,
            message: 'Profil berhasil disimpan ke akun online.',
          ),
        );
      } on CloudProfileSyncException {
        emit(
          state.copyWith(
            profile: updated,
            isSaving: false,
            message: 'Profil tersimpan di ponsel, tetapi belum diperbarui di akun online.',
          ),
        );
      }
    } else {
      emit(state.copyWith(message: 'Profil disimpan di ponsel.'));
    }
    return true;
  }

  /// Memvalidasi, menambah atau memperbarui kontak, lalu menyinkronkan cloud.
  Future<void> saveContact(EmergencyContact contact) async {
    final cleanedName = TextValidators.sanitizeSingleLine(contact.name);
    if (cleanedName.isEmpty ||
        cleanedName.runes.length > InputLimits.displayNameMaxLength) {
      emit(
        state.copyWith(
          message:
              'Nama kontak harus 1 sampai '
              '${InputLimits.displayNameMaxLength} karakter.',
        ),
      );
      return;
    }
    if (contact.phone.trim().isEmpty) {
      emit(state.copyWith(message: 'Nomor telepon kontak belum diisi.'));
      return;
    }
    final normalized = EmergencyContact(
      id: contact.id,
      name: cleanedName,
      phone: contact.phone.trim(),
      relationship: TextValidators.sanitizeSingleLine(contact.relationship),
    );
    final index = state.contacts.indexWhere((item) => item.id == normalized.id);
    if (index < 0 && state.contacts.length >= maximumContacts) {
      emit(state.copyWith(message: 'Maksimal tiga kontak darurat.'));
      return;
    }

    final updated = [...state.contacts];
    if (index < 0) {
      updated.add(normalized);
    } else {
      updated[index] = normalized;
    }
    await _save(
      () => _repository.saveContacts(updated),
      successMessage: 'Kontak disimpan di ponsel.',
    );
    if (state.message == 'Kontak disimpan di ponsel.') {
      emit(state.copyWith(contacts: List.unmodifiable(updated)));
    }
    await _syncContactsCloud(updated);
  }

  /// Menghapus kontak berdasarkan id lalu menyinkronkan perubahan ke cloud.
  Future<void> removeContact(String contactId) async {
    final updated = state.contacts
        .where((contact) => contact.id != contactId)
        .toList(growable: false);
    await _save(
      () => _repository.saveContacts(updated),
      successMessage: 'Kontak dihapus dari ponsel.',
    );
    if (state.message == 'Kontak dihapus dari ponsel.') {
      emit(state.copyWith(contacts: updated));
    }
    await _syncContactsCloud(updated);
  }

  /// Menyimpan avatar baru dan memperbarui byte avatar pada keadaan.
  Future<void> saveAvatar(Uint8List imageBytes) async {
    await _save(
      () => _repository.saveAvatar(imageBytes),
      successMessage: 'Foto profil diperbarui.',
    );
    if (state.message == 'Foto profil diperbarui.') {
      emit(state.copyWith(avatarBytes: imageBytes));
    }
  }

  /// Menghapus pesan status agar tidak ditampilkan kembali.
  void clearMessage() => emit(state.copyWith(clearMessage: true));

  /// Mengirim kontak ke cloud bila pengguna masuk, atau melaporkan kegagalan.
  Future<void> _syncContactsCloud(List<EmergencyContact> contacts) async {
    final cloudContactsRepository = _cloudContactsRepository;
    if (cloudContactsRepository == null ||
        _cloudRepository?.isCloudSignedIn != true) {
      return;
    }
    try {
      await cloudContactsRepository.saveCloudContacts(contacts);
    } on CloudProfileSyncException {
      if (!isClosed) {
        emit(
          state.copyWith(
            message: 'Kontak tersimpan di ponsel, tetapi belum diperbarui di akun online.',
          ),
        );
      }
    }
  }

  /// Menjalankan operasi simpan sambil mengatur status dan pesan hasilnya.
  Future<void> _save(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    emit(state.copyWith(isSaving: true, clearMessage: true));
    try {
      await operation();
      emit(state.copyWith(isSaving: false, message: successMessage));
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          message: 'Perubahan tidak dapat disimpan di ponsel.',
        ),
      );
    }
  }
}
