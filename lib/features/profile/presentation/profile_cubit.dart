import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/user_profile_repository.dart';
import '../domain/user_profile.dart';

class ProfileState {
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
  ProfileCubit(this._repository) : super(const ProfileState());

  static const maximumContacts = 3;
  final UserProfileRepository _repository;
  int _loadGeneration = 0;
  CloudUserProfileRepository? get _cloudRepository {
    if (_repository is! CloudUserProfileRepository) return null;
    return _repository as CloudUserProfileRepository;
  }

  Future<void> reloadProfile() async {
    emit(state.copyWith(isLoaded: false, clearMessage: true));
    await load();
  }

  Future<void> load() async {
    if (state.isLoaded) return;
    final generation = ++_loadGeneration;
    try {
      var profile = await _repository.loadProfile();
      final contacts = await _repository.loadContacts();
      Uint8List? avatar;
      String? message;
      try {
        avatar = await _repository.loadAvatar();
      } catch (_) {
        message = 'Foto profil tidak dapat dibuka.';
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
        } on CloudProfileSyncException catch (error) {
          message =
              'Profil lokal ditampilkan, tetapi sinkronisasi akun online gagal: $error';
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
          message: 'Data profil lokal tidak dapat dibuka.',
        ),
      );
    }
  }

  Future<bool> saveProfile(UserProfile profile) async {
    final cleanedName = profile.displayName.trim();
    if (cleanedName.isEmpty) {
      emit(state.copyWith(message: 'Nama tidak boleh kosong.'));
      return false;
    }
    if (cleanedName.length > 60) {
      emit(state.copyWith(message: 'Nama maksimal 60 karakter.'));
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
    emit(
      state.copyWith(profile: updated, isSaving: shouldSyncCloud),
    );
    if (shouldSyncCloud) {
      try {
        await cloudRepository!.saveCloudProfile(updated);
        emit(
          state.copyWith(
            profile: updated,
            isSaving: false,
            message: 'Profil tersimpan dan tersinkron ke akun online.',
          ),
        );
      } on CloudProfileSyncException catch (error) {
        emit(
          state.copyWith(
            profile: updated,
            isSaving: false,
            message:
                'Profil tersimpan di perangkat, tetapi sinkronisasi akun online gagal: $error',
          ),
        );
      }
    } else {
      emit(state.copyWith(message: 'Profil disimpan di perangkat.'));
    }
    return true;
  }

  Future<void> saveContact(EmergencyContact contact) async {
    final index = state.contacts.indexWhere((item) => item.id == contact.id);
    if (index < 0 && state.contacts.length >= maximumContacts) {
      emit(state.copyWith(message: 'Maksimal tiga kontak darurat.'));
      return;
    }

    final updated = [...state.contacts];
    if (index < 0) {
      updated.add(contact);
    } else {
      updated[index] = contact;
    }
    await _save(
      () => _repository.saveContacts(updated),
      successMessage: 'Kontak disimpan di perangkat.',
    );
    if (state.message == 'Kontak disimpan di perangkat.') {
      emit(state.copyWith(contacts: List.unmodifiable(updated)));
    }
  }

  Future<void> removeContact(String contactId) async {
    final updated = state.contacts
        .where((contact) => contact.id != contactId)
        .toList(growable: false);
    await _save(
      () => _repository.saveContacts(updated),
      successMessage: 'Kontak dihapus dari perangkat.',
    );
    if (state.message == 'Kontak dihapus dari perangkat.') {
      emit(state.copyWith(contacts: updated));
    }
  }

  Future<void> saveAvatar(Uint8List imageBytes) async {
    await _save(
      () => _repository.saveAvatar(imageBytes),
      successMessage: 'Foto profil diperbarui.',
    );
    if (state.message == 'Foto profil diperbarui.') {
      emit(state.copyWith(avatarBytes: imageBytes));
    }
  }

  void clearMessage() => emit(state.copyWith(clearMessage: true));

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
          message: 'Perubahan tidak dapat disimpan di perangkat.',
        ),
      );
    }
  }
}
