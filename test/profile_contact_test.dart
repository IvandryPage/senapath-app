import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:senapath/features/authentication/data/cloud_account_gateway.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';
import 'package:senapath/features/emergency/data/emergency_contact_actions.dart';
import 'package:senapath/features/emergency/presentation/emergency_cubit.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/profile/presentation/profile_cubit.dart';
import 'package:senapath/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('editing a saved emergency contact preloads its phone number', (
    tester,
  ) async {
    final repository = _TestProfileRepository()
      ..contacts = const [
        EmergencyContact(
          id: 'saved-contact',
          name: 'Ibu',
          phone: '+628123456789',
          relationship: 'Keluarga',
        ),
      ];
    final profileCubit = ProfileCubit(repository);
    await profileCubit.load();
    final cloudAccountCubit = CloudAccountCubit(_TestCloudAccountGateway());
    final emergencyCubit = EmergencyCubit(_TestEmergencyContactActions());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: profileCubit),
          BlocProvider.value(value: cloudAccountCubit),
          BlocProvider.value(value: emergencyCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kelola Ibu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final phoneField = tester.widget<PhoneFormField>(
      find.byType(PhoneFormField),
    );
    expect(phoneField.controller?.value?.international, '+628123456789');
    final phoneTextField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(PhoneFormField),
        matching: find.byType(TextField),
      ),
    );
    expect(phoneTextField.controller?.text, '8123456789');

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await profileCubit.close();
    await cloudAccountCubit.close();
    await emergencyCubit.close();
  });
}

class _TestProfileRepository implements UserProfileRepository {
  UserProfile profile = const UserProfile();
  List<EmergencyContact> contacts = [];

  @override
  Future<List<EmergencyContact>> loadContacts() async => contacts;

  @override
  Future<Uint8List?> loadAvatar() async => null;

  @override
  Future<UserProfile> loadProfile() async => profile;

  @override
  Future<void> saveAvatar(Uint8List imageBytes) async {}

  @override
  Future<void> saveContacts(List<EmergencyContact> value) async {
    contacts = value;
  }

  @override
  Future<void> saveProfile(UserProfile value) async {
    profile = value;
  }
}

class _TestCloudAccountGateway implements CloudAccountGateway {
  @override
  bool get isConfigured => false;

  @override
  String? get currentEmail => null;

  @override
  Stream<String?> get authChanges => const Stream.empty();

  @override
  Future<bool> get hasRememberedSession async => false;

  @override
  Future<CloudAccountRegistrationResult> register({
    required String email,
    required String password,
  }) async => const CloudAccountRegistrationResult(hasSession: false);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithRememberedSession() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> completePasswordReset({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _TestEmergencyContactActions implements EmergencyContactActions {
  @override
  Future<bool> call(EmergencyContact contact) async => true;

  @override
  Future<bool> openWhatsApp(EmergencyContact contact, String message) async =>
      true;
}
