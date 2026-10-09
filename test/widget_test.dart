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
import 'package:senapath/features/strategy_game/data/strategy_game_repository.dart';
import 'package:senapath/features/strategy_game/presentation/strategy_game_cubit.dart';
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
import 'package:drift/native.dart';

void main() {
  testWidgets('main shell navigates between core destinations', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final settingsCubit = UnitSettingsCubit(UnitSettingsRepository(database));
    await settingsCubit.load();
    final profileCubit = ProfileCubit(_FakeProfileRepository());
    await profileCubit.load();
    final logisticsCubit = LogisticsCubit(LogisticsRepository(database));
    final strategyGameCubit = StrategyGameCubit(
      StrategyGameRepository(database),
    );
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
        strategyGameCubit: strategyGameCubit,
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
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka Senapath'), findsNothing);
    final configuredApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(configuredApp.themeMode, ThemeMode.light);
    expect(configuredApp.darkTheme, isNull);
    expect(configuredApp.theme?.brightness, Brightness.light);

    await tester.drag(find.text('Hai, siap gowes?'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada sesi'), findsOneWidget);

    final leaderboardShortcut = find.byKey(
      const Key('home-shortcut-leaderboard'),
    );
    await tester.scrollUntilVisible(leaderboardShortcut, 400);
    await tester.tap(leaderboardShortcut);
    await tester.pumpAndSettle();
    expect(find.textContaining('Peringkat mingguan bersepeda'), findsOneWidget);
    expect(find.text('Partisipasi dan privasi'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Chat AI'), 400);
    await tester.tap(find.text('Chat AI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chat belum terhubung'), findsOneWidget);
    expect(
      find.textContaining('Chat akan aktif setelah backend Supabase'),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Saran & kesan'), 400);
    await tester.tap(find.text('Saran & kesan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mata Kuliah Pemrograman Aplikasi Mobile'),
      findsOneWidget,
    );
    expect(find.textContaining('Lorem ipsum dolor sit amet'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Kirim feedback'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Strategi rute'), 400);
    await tester.tap(find.text('Strategi rute'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Latihan strategi rute'), findsOneWidget);
    expect(find.text('Mulai tantangan'), findsOneWidget);
    await tester.tap(find.text('Mulai tantangan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Menjaga tempo terukur'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Menjaga tempo terukur'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.textContaining('Membandingkan situasi dengan rencana'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('Membandingkan situasi dengan rencana'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.textContaining('Membandingkan profil, jarak'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Membandingkan profil, jarak'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lihat hasil'), 250);
    await tester.tap(find.text('Lihat hasil'));
    await tester.pumpAndSettle();
    expect(find.text('Pilihan strategis: 3/3'), findsOneWidget);
    expect(strategyGameCubit.state.results, hasLength(1));
    await tester.binding.handlePopRoute();
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
    expect(find.text('Kontak darurat'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Tambah kontak darurat'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
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
    final profileScrollable = find
        .ancestor(
          of: find.text('Rute tersimpan'),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(profileScrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rute tersimpan'));
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
    expect(find.byTooltip('Detail sesi'), findsOneWidget);
    await tester.tap(find.byTooltip('Detail sesi'));
    await tester.pumpAndSettle();
    expect(find.text('Detail sesi'), findsNWidgets(2));
    expect(find.text('SIAP BERSEPEDA'), findsOneWidget);
    expect(find.text('Detail kesiapan & izin'), findsNothing);
    expect(find.text('Pemeriksaan pra-balapan'), findsNothing);
    expect(find.text('Pakai rute untuk sesi ini?'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Mulai sesi'));
    await tester.pumpAndSettle();
    expect(find.text('Pakai rute untuk sesi ini?'), findsOneWidget);
    expect(find.text('Mulai tanpa rute'), findsOneWidget);
    expect(find.text('Kelola rute'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(sessionCubit.state.session, isNull);
    await tester.tap(find.byTooltip('Tutup detail sesi'));
    await tester.pumpAndSettle();

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
    expect(find.text('Akun & keamanan'), findsOneWidget);
    expect(find.text('Akun online'), findsNothing);
    await tester.ensureVisible(find.text('Pengaturan'));
    await tester.tap(find.text('Pengaturan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tema terang'), findsOneWidget);
    expect(find.text('Gelap'), findsNothing);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme, isNull);
    expect(app.theme?.brightness, Brightness.light);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Akun & keamanan'));
    await tester.tap(find.text('Akun & keamanan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Lupa password?'), findsOneWidget);
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
    await strategyGameCubit.close();
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
