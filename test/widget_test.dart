import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:senapath/app/app.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/core/units/unit_settings_cubit.dart';
import 'package:senapath/core/units/unit_settings_repository.dart';
import 'package:senapath/core/widgets/feature_state_view.dart';
import 'package:senapath/features/authentication/data/supabase_cloud_account_gateway.dart';
import 'package:senapath/features/authentication/data/custom_auth_session_manager.dart';
import 'package:senapath/features/authentication/presentation/cloud_account_cubit.dart';
import 'package:senapath/features/assistant/data/supabase_ai_chat_gateway.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_cubit.dart';
import 'package:senapath/features/emergency/data/emergency_contact_actions.dart';
import 'package:senapath/features/emergency/presentation/emergency_cubit.dart';
import 'package:senapath/features/leaderboard/data/supabase_leaderboard_gateway.dart';
import 'package:senapath/features/leaderboard/presentation/leaderboard_cubit.dart';
import 'package:senapath/features/profile/data/user_profile_repository.dart';
import 'package:senapath/features/profile/domain/user_profile.dart';
import 'package:senapath/features/profile/presentation/profile_cubit.dart';
import 'package:senapath/features/logistics/data/logistics_repository.dart';
import 'package:senapath/features/logistics/presentation/logistics_cubit.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/routes/presentation/explore_map.dart';
import 'package:senapath/features/routes/presentation/routes_cubit.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/readiness_checker.dart';
import 'package:senapath/features/session/data/ride_session_repository.dart';
import 'package:senapath/features/session/data/session_file_service.dart';
import 'package:senapath/features/session/presentation/session_cubit.dart';
import 'package:senapath/features/progress/data/activity_goals_repository.dart';
import 'package:senapath/features/progress/presentation/activity_goals_cubit.dart';
import 'package:senapath/features/teams/data/cycling_team_repository.dart';
import 'package:senapath/features/teams/presentation/cycling_team_cubit.dart';
import 'package:senapath/features/notifications/data/notification_settings_repository.dart';
import 'package:senapath/features/notifications/data/ride_notification_service.dart';
import 'package:senapath/features/notifications/presentation/notification_settings_cubit.dart';
import 'package:senapath/features/gamification/data/rider_profile_repository.dart';
import 'package:senapath/features/gamification/presentation/rider_gamification_cubit.dart';
import 'package:senapath/features/ledger/data/ride_ledger_repository.dart';
import 'package:senapath/features/ledger/presentation/ride_ledger_cubit.dart';
import 'package:senapath/features/ride_coach/presentation/ride_coach_cubit.dart';
import 'package:senapath/features/ride_coach/data/ride_coach_gateway.dart';
import 'package:senapath/features/workouts/data/interval_workout_repository.dart';
import 'package:senapath/features/workouts/presentation/interval_workout_cubit.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('main shell navigates between core destinations', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final settingsCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await settingsCubit.load();
    final profileCubit = ProfileCubit(_FakeProfileRepository());
    await profileCubit.load();
    final logisticsCubit = LogisticsCubit(LogisticsRepository(database));
    final workoutRepository = IntervalWorkoutRepository(database);
    final intervalWorkoutCubit = IntervalWorkoutCubit(workoutRepository);
    await intervalWorkoutCubit.load();
    final emergencyCubit = EmergencyCubit(_FakeEmergencyContactActions());
    final routesCubit = RoutesCubit(
      SavedRouteRepository(
        database,
        geometryCodec: EncryptedTelemetryCodec(secureVault: _FakeSecureVault()),
      ),
      const RouteFileExchange(SessionFileService()),
    );
    final sessionCubit = RideSessionCubit(
      repository: DriftRideSessionRepository(
        database: database,
        telemetryCodec: EncryptedTelemetryCodec(
          secureVault: _FakeSecureVault(),
        ),
      ),
      readinessChecker: _FakeReadinessChecker(),
      locationSource: _FakeLocationSource(),
      intervalWorkoutRepository: workoutRepository,
    );
    await sessionCubit.initialize();

    await tester.pumpWidget(
      SenapathApp(
        cloudAccountCubit: CloudAccountCubit(
          SupabaseCloudAccountGateway(
            sessionManager: CustomAuthSessionManager(
              client: null,
              secureVault: _FakeSecureVault(),
            ),
          ),
        ),
        emergencyCubit: emergencyCubit,
        profileCubit: profileCubit,
        routesCubit: routesCubit,
        unitSettingsCubit: settingsCubit,
        sessionCubit: sessionCubit,
        logisticsCubit: logisticsCubit,
        aiChatCubit: AiChatCubit(
          SupabaseAiChatGateway(
            null,
            CustomAuthSessionManager(
              client: null,
              secureVault: _FakeSecureVault(),
            ),
          ),
        ),
        leaderboardCubit: LeaderboardCubit(
          SupabaseLeaderboardGateway(
            null,
            CustomAuthSessionManager(
              client: null,
              secureVault: _FakeSecureVault(),
            ),
          ),
        ),
        activityGoalsCubit: ActivityGoalsCubit(
          ActivityGoalsRepository(database),
        ),
        cyclingTeamCubit: CyclingTeamCubit(
          SupabaseCyclingTeamRepository(
            null,
            CustomAuthSessionManager(
              client: null,
              secureVault: _FakeSecureVault(),
            ),
          ),
        ),
        notificationSettingsCubit: NotificationSettingsCubit(
          NotificationSettingsRepository(database),
          _FakeRideNotificationService(),
        ),
        riderGamificationCubit: RiderGamificationCubit(
          RiderProfileRepository(database),
        ),
        rideLedgerCubit: RideLedgerCubit(RideLedgerRepository(database)),
        rideCoachCubit: RideCoachCubit(_UnavailableRideCoachGateway()),
        intervalWorkoutCubit: intervalWorkoutCubit,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka Senapath'), findsNothing);
    expect(find.text('Jelajah rute'), findsNothing);
    expect(find.text('Saran & kesan'), findsNothing);
    expect(find.text('Strategi rute'), findsNothing);
    expect(find.byKey(const Key('home-chat-ai')), findsOneWidget);
    final configuredApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(configuredApp.themeMode, ThemeMode.light);
    expect(configuredApp.darkTheme, isNull);
    expect(configuredApp.theme?.brightness, Brightness.light);

    await tester.scrollUntilVisible(
      find.text('Aktivitas terbaru'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada sesi'), findsOneWidget);

    final leaderboardShortcut = find.byKey(
      const Key('home-shortcut-leaderboard'),
    );
    await tester.scrollUntilVisible(leaderboardShortcut, 400);
    expect(find.text('Papan peringkat mingguan'), findsOneWidget);
    await tester.tap(leaderboardShortcut);
    await tester.pumpAndSettle();
    expect(find.textContaining('Peringkat mingguan bersepeda'), findsOneWidget);
    expect(find.text('Partisipasi dan privasi'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-chat-ai')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chat belum terhubung'), findsOneWidget);
    expect(
      find.textContaining('Chat akan aktif setelah backend Supabase'),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jelajah').last);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada rute tersimpan'), findsNothing);
    expect(find.byType(ExploreMap), findsOneWidget);
    expect(find.text('OpenStreetMap'), findsNothing);
    expect(find.byType(RichAttributionWidget), findsOneWidget);
    expect(find.byTooltip('Kompas utara tidak tersedia'), findsOneWidget);
    expect(find.byTooltip('Kunci arah utara'), findsOneWidget);
    await tester.tap(find.byTooltip('Kunci arah utara'));
    await tester.pump();
    expect(find.byTooltip('Ikuti arah gerak'), findsOneWidget);
    await tester.tap(find.byTooltip('Ikuti arah gerak'));
    await tester.pump();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Progres & target'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sesi terbaru'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sesi terbaru'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan dan menu profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kontak darurat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah kontak darurat'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneFormField), findsOneWidget);
    await tester.tap(find.byType(PhoneFormField));
    await tester.pumpAndSettle();
    final initialDialCode = tester
        .widget<Text>(find.textContaining('+ ').first)
        .data;
    await tester.tap(find.byType(FlagDialCodeChip).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '47');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('NO')));
    await tester.pumpAndSettle();
    expect(initialDialCode, isNot('+ 47'));
    expect(find.text('+ 47'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan dan menu profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rute tersimpan'));
    await tester.pumpAndSettle();
    expect(find.text('Perpustakaan rute'), findsOneWidget);
    expect(find.textContaining('Belum ada rute GPX.'), findsOneWidget);
    await tester.tap(find.text('Jelajah').last);
    await tester.pumpAndSettle();

    expect(find.byType(ExploreMap), findsOneWidget);
    expect(find.byTooltip('Kompas utara tidak tersedia'), findsOneWidget);
    expect(find.text('Cari rute GPX'), findsOneWidget);
    expect(find.text('SIAP BERSEPEDA'), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byKey(const Key('start-session-button')), findsOneWidget);
    expect(find.byTooltip('Detail sesi'), findsNothing);
    expect(sessionCubit.state.session, isNull);
    expect(find.text('Workout'), findsOneWidget);
    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle();
    expect(find.text('Workout interval'), findsAtLeastNWidgets(1));
    expect(find.text('Buat workout'), findsOneWidget);
    await tester.tap(find.text('Buat workout'));
    await tester.pumpAndSettle();
    final workoutFields = find.byType(TextFormField);
    await tester.enterText(workoutFields.at(0), 'Latihan singkat');
    await tester.enterText(workoutFields.at(1), 'Interval awal');
    await tester.enterText(workoutFields.at(2), '1');
    await tester.tap(find.text('Simpan workout'));
    await tester.pumpAndSettle();
    expect(find.text('Latihan singkat'), findsOneWidget);
    await tester.tap(find.text('Pilih untuk sesi berikutnya'));
    await tester.pumpAndSettle();
    expect(intervalWorkoutCubit.state.selectedWorkout?.name, 'Latihan singkat');

    await tester.tap(find.text('Logistik').last);
    await tester.pumpAndSettle();
    expect(find.text('Anggaran'), findsOneWidget);
    expect(find.text('Waktu acara'), findsOneWidget);

    await tester.tap(find.byTooltip('Atur kurs'));
    await tester.pumpAndSettle();
    final rateFields = find.byType(TextFormField);
    await tester.enterText(rateFields.at(0), '17000');
    await tester.enterText(rateFields.at(1), '1.1');
    await tester.enterText(rateFields.at(2), '0.95');
    await tester.tap(find.text('Simpan kurs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bukan real-time'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('eur-converter-amount')), '10');
    await tester.pump();
    expect(find.textContaining('170,000'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Tambah item anggaran'));
    await tester.tap(find.byTooltip('Tambah item anggaran'));
    await tester.pumpAndSettle();
    final itemFields = find.byType(TextFormField);
    await tester.enterText(itemFields.at(0), 'Hotel');
    await tester.enterText(itemFields.at(1), '100');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Hotel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '125');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus Hotel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(find.text('Hotel'), findsNothing);

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Perpustakaan rute'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sesi terbaru'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sesi terbaru'), findsOneWidget);
    expect(find.text('Akun online'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan dan menu profil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pengaturan aplikasi'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Pengaturan aplikasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('Tema terang'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Tema terang'), findsOneWidget);
    expect(find.text('Gelap'), findsNothing);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme, isNull);
    expect(app.theme?.brightness, Brightness.light);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan dan menu profil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Akun & keamanan'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Akun & keamanan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Lupa password?'), findsNothing);
    expect(find.textContaining('Supabase belum dikonfigurasi'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Beranda').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
    await profileCubit.close();
    await emergencyCubit.close();
    await routesCubit.close();
    await settingsCubit.close();
    await sessionCubit.close();
    await logisticsCubit.close();
    await intervalWorkoutCubit.close();
  });

  testWidgets('loading state is announced with progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FeatureStateView.loading(message: 'Memuat rute')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Memuat rute'), findsOneWidget);
  });

  testWidgets('error state exposes retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeatureStateView.error(
            message: 'Koneksi tidak tersedia',
            onAction: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Koneksi tidak tersedia'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });
}

class _FakeProfileRepository implements UserProfileRepository {
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

class _FakeReadinessChecker implements ReadinessChecker {
  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openLocationServiceSettings() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<ReadinessReport> check({
    bool requestLocationPermission = false,
    bool requestNotificationPermission = false,
    bool checkGpsFix = false,
  }) async => ReadinessReport(
    locationPermissionGranted: true,
    backgroundLocationGranted: false,
    locationPermanentlyDenied: false,
    locationServicesEnabled: true,
    gpsFixAvailable: true,
    accelerometerAvailable: true,
    gyroscopeAvailable: true,
    notificationsGranted: requestNotificationPermission,
    notificationsPermanentlyDenied: false,
    gpsAccuracyMeters: 8,
    gpsFixChecked: true,
  );
}

class _FakeLocationSource implements LocationSource {
  @override
  Stream<Position> get positions => const Stream<Position>.empty();
}

class _FakeSecureVault implements SecureVault {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _FakeEmergencyContactActions implements EmergencyContactActions {
  @override
  Future<bool> call(EmergencyContact contact) async => true;

  @override
  Future<bool> openWhatsApp(EmergencyContact contact, String message) async =>
      true;
}

class _FakeRideNotificationService implements RideNotificationService {
  @override
  Future<void> cancelWeeklyReminders() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleWeeklyReminder({
    required Set<int> weekdays,
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
}

class _UnavailableRideCoachGateway implements RideCoachGateway {
  @override
  bool get isConfigured => false;

  @override
  bool get isSignedIn => false;

  @override
  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  }) async => throw StateError('Not configured');

  @override
  Future<String> diagnoseConfiguration() async => 'Not configured';
}
