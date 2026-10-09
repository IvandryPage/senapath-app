import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/features/authentication/data/cloud_account_gateway.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';
import 'package:senapath/features/emergency/data/emergency_contact_actions.dart';
import 'package:senapath/features/emergency/presentation/emergency_cubit.dart';
import 'package:senapath/features/gamification/data/rider_profile_repository.dart';
import 'package:senapath/features/gamification/presentation/rider_gamification_cubit.dart';
import 'package:senapath/features/progress/data/activity_goals_repository.dart';
import 'package:senapath/features/progress/presentation/activity_goals_cubit.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/profile/presentation/profile_cubit.dart';
import 'package:senapath/features/profile/presentation/profile_screen.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/readiness_checker.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/presentation/session_cubit.dart';
import 'package:senapath/features/teams/data/cycling_team_repository.dart';
import 'package:senapath/features/teams/domain/cycling_team.dart';
import 'package:senapath/features/teams/presentation/cycling_team_cubit.dart';

void main() {
  testWidgets('editing a saved emergency contact preloads its phone number', (
    tester,
  ) async {
    final repository = _TestProfileRepository()
      ..profile = const UserProfile(teamName: 'Nama tim manual lama')
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
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final vault = _TestSecureVault();
    final sessionCubit = RideSessionCubit(
      repository: DriftRideSessionRepository(
        database: database,
        telemetryCodec: EncryptedTelemetryCodec(secureVault: vault),
      ),
      readinessChecker: const _TestReadinessChecker(),
      locationSource: const _TestLocationSource(),
    );
    final goalsCubit = ActivityGoalsCubit(ActivityGoalsRepository(database));
    final unitCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    final riderCubit = RiderGamificationCubit(RiderProfileRepository(database));
    final teamCubit = CyclingTeamCubit(
      _TestCyclingTeamRepository([
        const CyclingTeam(
          id: 'team-1',
          name: 'Tim dari akun',
          inviteCode: '',
          role: 'member',
          memberCount: 2,
        ),
      ]),
    );
    await unitCubit.load();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: profileCubit),
          BlocProvider.value(value: cloudAccountCubit),
          BlocProvider.value(value: emergencyCubit),
          BlocProvider.value(value: sessionCubit),
          BlocProvider.value(value: goalsCubit),
          BlocProvider.value(value: unitCubit),
          BlocProvider.value(value: riderCubit),
          BlocProvider.value(value: teamCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tim dari akun'), findsOneWidget);
    expect(find.text('Nama tim manual lama'), findsNothing);

    await tester.tap(find.byTooltip('Edit nama dan foto profil'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Tim (opsional)'), findsNothing);
    expect(find.text('Ubah foto'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Isi nama.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Rider Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repository.profile.displayName, 'Rider Baru');
    expect(repository.profile.teamName, 'Nama tim manual lama');
    expect(find.byTooltip('Edit nama dan foto profil'), findsOneWidget);

    await tester.tap(find.byTooltip('Pengaturan dan menu profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kontak darurat'));
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
    await sessionCubit.close();
    await goalsCubit.close();
    await unitCubit.close();
    await teamCubit.close();
    await riderCubit.close();
    await database.close();
  });
}

class _TestCyclingTeamRepository implements CyclingTeamRepository {
  _TestCyclingTeamRepository(this.teams);

  final List<CyclingTeam> teams;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<List<CyclingTeam>> loadTeams() async => teams;

  @override
  Future<CyclingTeam> createTeam(String name, String displayName) =>
      throw UnimplementedError();

  @override
  Future<CyclingTeam> joinTeam(String inviteCode, String displayName) =>
      throw UnimplementedError();

  @override
  Future<CyclingTeamDashboard> loadDashboard(String teamId) =>
      throw UnimplementedError();

  @override
  Future<void> leaveTeam(String teamId) => throw UnimplementedError();

  @override
  Future<void> unshareSession(String teamId, String sessionId) =>
      throw UnimplementedError();

  @override
  Future<void> setMemberRole(String teamId, String userId, String role) =>
      throw UnimplementedError();
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

class _TestSecureVault implements SecureVault {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

class _TestReadinessChecker implements ReadinessChecker {
  const _TestReadinessChecker();

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async => const ReadinessReport(
    locationPermissionGranted: false,
    locationPermanentlyDenied: false,
    locationServicesEnabled: false,
    gpsFixAvailable: false,
    accelerometerAvailable: false,
    gyroscopeAvailable: false,
    notificationsGranted: false,
    notificationsPermanentlyDenied: false,
  );

  @override
  Future<bool> openLocationServiceSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;
}

class _TestLocationSource implements LocationSource {
  const _TestLocationSource();

  @override
  Stream<Position> get positions => const Stream.empty();
}
