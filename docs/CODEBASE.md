# Senapath - Dokumentasi Codebase

Dokumen ini menjelaskan struktur, arsitektur, data, alur utama, dan aturan
keamanan aplikasi Senapath. Gunakan bersama:

- [docs/UML.md](UML.md) - diagram PlantUML (use case, activity, class, sequence)
- [agents/vision.md](../agents/vision.md) - visi dan pilar produk
- [agents/architecture.md](../agents/architecture.md) - keputusan arsitektur
- [agents/requirements.md](../agents/requirements.md) - kebutuhan produk
- [agents/tech-stack.md](../agents/tech-stack.md) - pilihan teknologi

Terakhir diperbarui: 23 Oktober 2026.

---

## 1. Ringkasan

Senapath adalah aplikasi Flutter untuk merekam perjalanan sepeda, merencanakan
rute, berlatih, memantau progres, dan terhubung dengan tim. Aplikasi memakai
pendekatan **offline-first**: fitur inti tetap berjalan tanpa jaringan, lalu
data disinkronkan ke akun Supabase ketika pengguna masuk dan memberi izin.

Prinsip utama:

1. **Lokal dulu.** Rekaman perjalanan, telemetri, rute, riwayat, dan pengaturan
   disimpan di perangkat memakai Drift. Cloud bersifat opsional.
2. **Izin eksplisit.** Sinkronisasi sesi, leaderboard, dan anchor blockchain
   hanya berjalan setelah pengguna menyetujui.
3. **Rahasia tetap di server.** Service-role key, signing secret JWT, Gemini API
   key, dan private key relayer tidak pernah masuk ke aplikasi Flutter.
4. **Verifikasi mandiri.** Anchor blockchain diverifikasi langsung dari node
   RPC publik, bukan hanya dari respons server Senapath.
5. **Data sensitif dienkripsi saat istirahat.** Telemetri dan geometri rute
   dienkripsi lokal dengan AES-256-GCM; kunci berada di secure storage.

---

## 2. Teknologi

| Lapisan | Teknologi |
| --- | --- |
| UI | Flutter, Material 3, `go_router`, `flutter_bloc` |
| Peta | `flutter_map`, `latlong2` |
| Lokasi/sensor | `geolocator`, `sensors_plus`, `flutter_compass` |
| Database lokal | Drift (SQLite) + `drift_flutter` |
| Penyimpanan rahasia | `flutter_secure_storage` |
| Kriptografi | `cryptography` (AES-256-GCM, SHA-256) |
| Backend | Supabase Postgres, RLS, RPC, Edge Functions (Deno/TypeScript) |
| Autentikasi | Custom `app-auth` (PBKDF2 + app JWT HS256), bukan Supabase Auth |
| AI | Gemini melalui Edge Function `rider-assistant` dan `rider-coach` |
| Blockchain | Ethereum Sepolia, relayer server-side, verifikasi JSON-RPC |
| Notifikasi | `flutter_local_notifications` |
| Lain-lain | `file_selector`, `share_plus`, `image_picker`, `local_auth`, `url_launcher`, `wakelock_plus`, `flutter_timezone`, `flutter_dotenv` |

Konfigurasi publik Flutter berada di `.env`, lalu disalin oleh
`scripts/flutter_with_env.ps1` menjadi `assets/config/client.env`. Hanya
`SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` yang masuk ke aplikasi.

---

## 3. Struktur repository

```text
senapath-app/
|-- lib/
|   |-- main.dart                 # bootstrap, konfigurasi, dependency injection
|   |-- app/
|   |   |-- app.dart              # root widget, BlocProvider, listener akun/sesi
|   |   |-- router/app_router.dart# semua route go_router + shell navigasi
|   |   `-- theme/app_theme.dart  # tema terang/gelap
|   |-- core/
|   |   |-- storage/              # Drift AppDatabase, secure vault
|   |   |-- units/                # pengaturan satuan km/mil
|   |   |-- validation/           # validator dan input formatter
|   |   `-- widgets/              # widget bersama
|   `-- features/
|       |-- <fitur>/
|       |   |-- domain/           # model, aturan bisnis, interface
|       |   |-- data/             # Drift, Supabase, HTTP, file, sensor
|       |   `-- presentation/     # Cubit, state, screen, widget
|-- supabase/
|   |-- functions/                # Edge Functions dan kode _shared
|   `-- migrations/               # skema, RLS, RPC
|-- test/                         # unit dan widget test
|-- scripts/                      # runner flutter + env
|-- assets/                       # config, gambar, ikon
`-- agents/                       # dokumen produk dan arsitektur
```

Konvensi fitur:

- `domain/` tidak mengimpor Flutter UI atau Supabase.
- `data/` mengimplementasikan interface dari `domain/`.
- `presentation/` berisi `Cubit`, state immutable, dan widget.
- Dependency dibuat di `main.dart` dan diberikan lewat constructor; tidak ada
  service locator global.
- Feature tidak saling mengakses widget internal. Komunikasi lintas fitur
  terjadi lewat Cubit, repository, atau gateway di root aplikasi.

---

## 4. Bootstrap dan runtime

### 4.1 `lib/main.dart`

Urutan startup:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Memuat `.env`; jika gagal, aplikasi tetap berjalan dalam mode lokal.
3. `Supabase.initialize(...)` hanya jika URL dan publishable key tersedia.
4. Membuat `FlutterSecureVault`, `CustomAuthSessionManager`, `AppDatabase`, dan
   seluruh repository/gateway.
5. Membuat Cubit yang perlu hidup selama aplikasi berjalan.
6. `runApp(SenapathApp(...))` dengan semua Cubit sebagai properti.

Supabase bersifat opsional. `SupabaseClient?` yang `null` membuat fitur cloud
menampilkan status "belum dikonfigurasi", sedangkan fitur lokal tetap bekerja.

### 4.2 `lib/app/app.dart`

`SenapathApp`:

- Mendaftarkan 16 Cubit lewat `MultiBlocProvider`.
- `BlocListener<CloudAccountCubit>` mereset state milik akun saat email berubah:
  percakapan AI, sinkronisasi tertunda, leaderboard, tim, gamifikasi.
- Saat pengguna masuk, aplikasi memuat sesi lokal, menarik sesi cloud,
  menyegarkan gamifikasi, lalu menyinkronkan sesi tertunda.
- `BlocListener<RideSessionCubit>` meneruskan rekor sesi lokal ke leaderboard.
- `MaterialApp.router` memakai tema terang/gelap. Mode tema mengikuti sistem,
  kecuali sensor cahaya ambien menentukan mode saat merekam perjalanan.

### 4.3 `lib/app/router/app_router.dart`

Aplikasi memakai `StatefulShellRoute.indexedStack` dengan empat tab:

| Tab | Path akar | Isi |
| --- | --- | --- |
| Beranda | `/` | Overview, asisten AI, feedback, leaderboard, progres, akun, profil pesepeda, bukti perjalanan, mini games |
| Jelajah | `/routes` | Pencarian/rute GPX, latihan interval, rute tersimpan |
| Logistik | `/logistics` | Budget, kurs, zona waktu, resupply |
| Profil | `/profile` | Profil, riwayat sesi, pengaturan, notifikasi, tim |

Route penting:

| Path | Layar |
| --- | --- |
| `/` | `OverviewScreen` |
| `/assistant` | `AiChatScreen` |
| `/feedback` | `FeedbackScreen` |
| `/leaderboard` | `LeaderboardScreen` |
| `/progress` | `ActivityProgressScreen` |
| `/account` | `CloudAccountScreen` |
| `/rider` | `RiderScreen` |
| `/rider/ledger` | `RideLedgerScreen` (Bukti perjalanan) |
| `/rider/minigames` | `MiniGameScreen` |
| `/routes` | `RoutesScreen` |
| `/routes/workouts` | `IntervalWorkoutScreen` |
| `/routes/saved` | `SavedRoutesScreen` |
| `/logistics` | `LogisticsScreen` |
| `/profile` | `ProfileScreen` |
| `/profile/sessions` | Riwayat perjalanan |
| `/profile/sessions/:sessionId` | Detail perjalanan |
| `/profile/settings` | `ProfileSettingsScreen` |
| `/profile/notifications` | `NotificationSettingsScreen` |
| `/profile/teams` | Daftar tim |
| `/profile/teams/:teamId` | Dashboard tim |

`_AppShell` juga berfungsi sebagai gerbang akun. Jika Supabase dikonfigurasi,
pengguna harus menyelesaikan inisialisasi sesi; jika belum masuk, layar
`CloudAccountScreen(isEntryFlow: true)` ditampilkan. Ini bukan gerbang
enkripsi perangkat, hanya gerbang fitur akun cloud.

---

## 5. Katalog fitur

| Fitur | Tanggung jawab | Kelas/file kunci |
| --- | --- | --- |
| `overview` | Beranda, ringkasan aktivitas, akses cepat, status sesi | `OverviewScreen` |
| `session` | Rekam, jeda, lanjut, selesai, telemetri, pemulihan sesi, sinkronisasi | `RideSessionCubit`, `RideSessionRepository`, `DriftRideSessionRepository`, `EncryptedTelemetryCodec` |
| `routes` | Impor/ekspor GPX, rute tersimpan, navigasi, ghost pacer, angin, cuaca, POI | `RoutesCubit`, `SavedRouteRepository`, `RouteFileExchange`, `GhostPacerService`, `RouteWindService`, `OpenMeteoPreRideWeatherService`, `OverpassRoutePlacesService` |
| `ride_coach` | Rekomendasi latihan dan briefing pra-perjalanan | `RideCoachCubit`, `SupabaseRideCoachGateway` |
| `ride_prediction` | Estimasi durasi rute dengan KNN lokal | `RideHistoryRepository`, `RideTimePredictor` |
| `workouts` | Latihan interval dan sesi terstruktur | `IntervalWorkoutCubit`, `IntervalWorkoutRepository` |
| `logistics` | Budget perjalanan, kurs, zona waktu, resupply | `LogisticsCubit`, `LogisticsRepository` |
| `authentication` | Daftar, masuk, refresh sesi, keluar, biometrik | `CloudAccountCubit`, `CustomAuthSessionManager`, `SupabaseCloudAccountGateway`, `BiometricSignInSettingsRepository` |
| `account_sync` | Sinkronisasi sesi penuh, telemetri, pengaturan akun, progres | `SupabaseAccountCloudGateway`, `AccountCloudGateway` |
| `ledger` | Rantai bukti lokal, sinkronisasi cloud, anchor Sepolia, verifikasi | `RideLedgerRepository`, `RideLedgerCubit`, `SupabaseRideLedgerSyncGateway`, `EvmRpcClient`, `RideLedgerAnchorVerifier` |
| `profile` | Profil pengguna, avatar terenkripsi, sinkronisasi profil | `ProfileCubit`, `SecureUserProfileRepository`, `EncryptedAvatarStore` |
| `emergency` | Kontak darurat dan aksi panggilan/pesan | `EmergencyCubit`, `UrlLauncherEmergencyContactActions` |
| `gamification` | Level, XP, gaya pesepeda, mini games | `RiderGamificationCubit`, `RiderProfileRepository` |
| `leaderboard` | Papan peringkat mingguan dan rekor pribadi, opt-in | `LeaderboardCubit`, `SupabaseLeaderboardGateway` |
| `progress` | Target aktivitas harian/mingguan | `ActivityGoalsCubit`, `ActivityGoalsRepository` |
| `teams` | Buat/gabung/kelola tim, bagikan ringkasan | `CyclingTeamCubit`, `SupabaseCyclingTeamRepository` |
| `assistant` | Chat AI dengan kuota harian | `AiChatCubit`, `SupabaseAiChatGateway` |
| `feedback` | Kirim saran dan kesan | `FeedbackScreen` |
| `notifications` | Preferensi dan notifikasi lokal saat merekam | `NotificationSettingsCubit`, `LocalRideNotificationService` |

---

## 6. Data lokal (Drift)

`AppDatabase` berada di `lib/core/storage/app_database.dart` dan memakai nama
database `senapath`. Schema version saat ini **9**.

| Tabel | Kolom utama | Keterangan |
| --- | --- | --- |
| `AppPreferences` | `key` (PK), `value` | Preferensi umum, termasuk rantai bukti `ride_proof_chain_v1` |
| `RideSessions` | `id` (PK), `title`, `activityType`, `source`, `startedAt`, `endedAt`, `pausedAt`, `totalPausedMilliseconds`, `status`, `syncStatus`, `distanceMeters`, `currentSpeedMetersPerSecond`, `gpsAccuracyMeters` | Metadata sesi aktif/selesai |
| `TelemetryPoints` | `id` (PK autoincrement), `sessionId` (FK), `recordedAt`, `encryptedPayload` | Titik GPS/sensor; payload AES-GCM |
| `SavedRoutes` | `id` (PK), `name`, `source`, `description`, `updatedAt`, `distanceMeters`, `elevationGainMeters`, `poiSummary`, `availability`, `encryptedGeometry` | Rute GPX; geometri terenkripsi |
| `RideHistory` | `sessionId` (PK), `distanceKm`, `elevationGainMeters`, `elevationPerDistance`, `durationMinutes`, `completedAt` | Fitur untuk prediksi durasi KNN |

Catatan:

- Migrasi Drift ditangani di `onUpgrade`; versi 8 menghapus tabel mini game
  lama, versi 9 menambah `RideHistory`.
- Status sesi dan sinkronisasi disimpan sebagai string yang dipetakan ke enum
  domain.
- Kunci enkripsi telemetri dibuat sekali dan disimpan di `SecureVault` dengan
  nama `senapath.telemetry.encryption_key`. Kunci yang sama dipakai untuk
  geometri rute.
- Telemetri lokal tidak dapat dibaca tanpa kunci di secure storage. Kehilangan
  kunci berarti data lama tidak dapat didekripsi.

---

## 7. Backend Supabase

Project referensi: `rngyzesuzwlwmqvcdybn`. Semua akses data klien memakai
publishable key dan JWT pengguna; Edge Function memakai service role hanya di
server.

### 7.1 Tabel utama

| Kelompok | Tabel | Fungsi |
| --- | --- | --- |
| Autentikasi | `app_users`, `app_auth_sessions`, `app_auth_password_resets`, `app_auth_email_verifications`, `app_auth_rate_limits` | Akun custom, hash password, sesi refresh, rate limit. Tabel auth hanya dapat diakses service role. |
| Profil | `rider_profiles`, `leaderboard_preferences` | Gaya/level/XP pesepeda dan preferensi leaderboard |
| Sesi | `ride_session_summaries`, `ride_sessions`, `ride_session_telemetry` | Ringkasan untuk tim/leaderboard, sesi penuh, dan titik telemetri untuk sinkronisasi akun |
| Sosial | `cycling_teams`, `cycling_team_members`, `team_shared_ride_summaries` | Tim, peran, undangan, tautan ringkasan yang dibagikan |
| AI | `ai_chat_daily_usage` | Kuota chat harian per akun |
| Progres | `account_settings` | Dokumen JSONB per akun: target aktivitas, kontak darurat, logistik |
| Bukti | `ride_proof_cloud_heads`, `ride_proof_cloud_blocks`, `ride_proof_chain_anchors` | Ledger cloud dan catatan anchor blockchain |
| Lain-lain | `user_feedback`, `weekly_cycling_leaderboard` | Feedback dan data leaderboard |

Semua tabel data pengguna memakai RLS. Tabel auth dan rate limit mencabut akses
`anon`/`authenticated` dan hanya memberi akses ke `service_role`. RPC yang
memerlukan identitas memakai `security definer`, `set search_path = ''`, dan
memvalidasi `auth.uid()`.

### 7.2 RPC penting

| RPC | Kegunaan |
| --- | --- |
| `register_app_user`, `rotate_app_auth_session`, `revoke_app_auth_session`, `consume_app_auth_rate_limit` | Autentikasi custom |
| `set_my_account_profile`, `set_my_rider_profile`, `set_my_rider_progress` | Profil dan progres |
| `get_leaderboard_settings`, `set_leaderboard_consent`, `record_my_leaderboard_ride`, `get_weekly_cycling_leaderboard` | Leaderboard opt-in dan rekor |
| `create_cycling_team`, `join_cycling_team`, `get_cycling_team_invite_code`, `leave_cycling_team`, `set_cycling_team_member_role`, `delete_cycling_team` | Manajemen tim |
| `consume_ai_chat_quota` | Kuota chat |
| `append_my_ride_proof_blocks` | Menambah blok bukti cloud secara idempoten |
| `reserve_ride_proof_anchor` | Reservasi anchor, validasi head, dan rate limit 10 menit |

### 7.3 Edge Functions

| Function | Auth | Kegunaan |
| --- | --- | --- |
| `app-auth` | Publik untuk register/sign-in/refresh/sign-out | Hash PBKDF2-HMAC-SHA256 (600.000 iterasi), membuat sesi refresh 30 hari, menerbitkan app JWT HS256 |
| `rider-assistant` | App JWT | Chat AI dengan kuota harian dan Gemini |
| `rider-coach` | App JWT | Rekomendasi latihan dan briefing |
| `sync-ride-proofs` | App JWT | Validasi consent dan meneruskan blok ke RPC cloud |
| `anchor-ride-proofs` | App JWT | Aksi `anchor` dan `list`, mengirim transaksi relayer ke Sepolia |

`supabase/functions/_shared/app_auth.ts` memverifikasi JWT aplikasi secara
manual karena project tidak memakai Supabase Auth. JWT memakai
`role=authenticated`, `aud=authenticated`, dan `sub=<app_users.id>` agar
`auth.uid()` pada RLS tetap bekerja. `verify_jwt` pada function yang memakai
auth custom harus dimatikan; function melakukan verifikasi sendiri.

### 7.4 Autentikasi custom

1. Klien mengirim email/password ke `app-auth`.
2. Server menormalkan email, memeriksa rate limit, lalu memverifikasi
   PBKDF2. Password asli tidak pernah disimpan.
3. Server membuat refresh token acak, menyimpan hash-nya di
   `app_auth_sessions`, dan menerbitkan access token JWT berumur pendek.
4. Klien menyimpan token di secure storage. Refresh token selalu dirotasi.
5. `sign-out` mencabut sesi di server dan menghapus token lokal.
6. Login biometrik hanya membuka sesi tersimpan lewat `local_auth`; password
   tidak disimpan dan biometrik bukan gerbang seluruh aplikasi.

Konsekuensi yang disengaja: tidak ada verifikasi email, tidak ada pemulihan
password, dan akun lama tanpa password custom tidak dapat diklaim hanya dengan
mengetahui alamat email.

---

## 8. Alur data utama

### 8.1 Startup dan akun

1. `main.dart` memuat konfigurasi dan membuat dependency.
2. `_AppShell` memanggil `CloudAccountCubit.initialize()`.
3. `CustomAuthSessionManager` memulihkan token dari secure storage dan
   me-refresh sesi jika perlu.
4. Jika belum masuk dan Supabase dikonfigurasi, layar akun entry-flow tampil.
5. Setelah masuk, listener akun memuat ulang data akun, menarik sesi cloud,
   lalu menyinkronkan sesi lokal yang tertunda.

### 8.2 Merekam perjalanan

1. Pengguna memilih rute/latihan (opsional) dan menekan mulai.
2. `RideSessionCubit.start()` memeriksa izin lokasi, notifikasi, sensor, dan
   kesiapan perangkat.
3. Repository membuat sesi `recording` di Drift.
4. Stream lokasi, barometer, akselerometer, giroskop, dan cahaya ambien mulai.
5. Setiap titik dibungkus `TelemetryLocation`, dienkripsi AES-GCM, lalu
   disimpan ke `TelemetryPoints`.
6. Jeda menghentikan stream dan mencatat `pausedAt`; lanjut melanjutkan stream.
7. Selesai: sesi menjadi `completed`, lalu:
   - `RideLedgerRepository.appendSession()` menambah blok bukti lokal;
   - `RideHistoryRepository.recordCompletedRide()` menyimpan fitur prediksi;
   - jika auto-sync aktif, sesi didorong ke cloud.

### 8.3 Sinkronisasi sesi

Ada dua jalur cloud:

- **Ringkasan** (`SessionSyncCoordinator` + `SupabaseSessionSyncGateway`):
  ringkasan sesi untuk leaderboard/tim. Wajib login dan consent.
- **Sesi penuh** (`RideSessionCloudSync` + `SupabaseAccountCloudGateway`):
  metadata sesi dan seluruh telemetri, dibagi per batch 500 titik. Data cloud
  menjadi sumber pemulihan lintas perangkat.

Saat menarik sesi cloud, data digabung dengan sesi lokal. Konflik diselesaikan
berdasarkan status sinkronisasi dan data terbaru; detail ada di
`RideSessionCloudSync` dan `RideSessionCubit`.

### 8.4 Bukti perjalanan (ledger lokal)

`RideLedgerRepository` menyimpan satu JSON array di
`AppPreferences['ride_proof_chain_v1']`.

Setiap blok berisi:

```json
{
  "index": 0,
  "sessionId": "uuid",
  "createdAt": "2026-10-23T08:00:00.000Z",
  "distanceMeters": 12500.0,
  "durationSeconds": 2400,
  "previousHash": "000...000",
  "hash": "sha256(canonical-json)"
}
```

Aturan:

- Genesis hash adalah 64 karakter `0`.
- Hash adalah SHA-256 dari JSON kanonik dengan urutan field: `index`,
  `sessionId`, `createdAt`, `distanceMeters`, `durationSeconds`,
  `previousHash`.
- Penambahan blok memakai write lock agar tidak ada dua penulisan bersamaan.
- Sesi dengan ID yang sudah ada tidak ditambahkan dua kali.
- Verifikasi memeriksa urutan index, `previousHash`, nilai numerik, dan
  recomputasi hash setiap blok.
- Ledger ini membuktikan integritas lokal, bukan identitas pengguna. Jika
  perangkat dan kunci dikuasai pihak lain, ledger dapat ditulis ulang; anchor
  on-chain membatasi klaim pada head hash yang sudah dipublikasikan.

### 8.5 Sinkronisasi dan anchor blockchain

Alur tombol **Bukti perjalanan**:

1. `RideLedgerCubit.sync()` memuat blok lokal, lalu mengirim semuanya ke
   `sync-ride-proofs`.
2. Edge Function memvalidasi consent dan jumlah blok, lalu memanggil RPC
   `append_my_ride_proof_blocks`. RPC bersifat idempoten.
3. `RideLedgerCubit.anchor()` selalu menyinkronkan dahulu, lalu memanggil
   `anchor-ride-proofs` dengan aksi `anchor`.
4. Server memanggil `reserve_ride_proof_anchor` untuk memvalidasi head cloud,
   mencegah anchor ganda, dan menerapkan rate limit 10 menit per akun.
5. Server membangun calldata `senapath:v1:<jumlah_blok>:<head_hash>` dan
   mengirim transaksi bernilai 0 dari relayer lewat `eth_sendRawTransaction`.
6. Status anchor dicatat (`pending`, `confirmed`, `failed`) dan daftar anchor
   disegarkan dari node RPC.
7. Verifikasi klien memanggil `EthRpcClient` langsung ke RPC publik:
   - chain ID harus sama;
   - transaksi harus ditemukan dan sudah masuk blok;
   - receipt harus sukses;
   - `from` harus alamat relayer;
   - calldata harus sama dengan payload yang diharapkan;
   - hash head pada blok lokal indeks `blockCount - 1` harus sama dengan
     `headHash`.

Konfigurasi default Sepolia:

| Variabel | Nilai default |
| --- | --- |
| Chain ID | `11155111` |
| Nama | `Ethereum Sepolia (testnet)` |
| Explorer | `https://sepolia.etherscan.io` |
| RPC publik | `https://ethereum-sepolia-rpc.publicnode.com` |

Catatan keamanan: private key relayer hanya ada di secret Supabase. Biaya gas
ditanggung relayer. Anchor membuktikan bahwa sebuah head hash ada pada waktu
tertentu; anchor tidak membuktikan bahwa seluruh data telemetri benar.

### 8.6 AI

- `AiChatCubit` mengirim maksimal 20 pesan ke `rider-assistant`.
- Function memeriksa kuota lewat `consume_ai_chat_quota`, memetakan peran
  `assistant` menjadi `model`, lalu memanggil Gemini.
- API key Gemini hanya ada di secret Edge Function.
- `rider-coach` menyediakan rekomendasi latihan dan briefing dengan pola auth
  yang sama.
- Percakapan dibersihkan saat akun berubah agar data tidak tercampur.

### 8.7 Tim dan leaderboard

- Tim dibuat dengan nama dan kode undangan 32 karakter heksadesimal.
- Peran: `manager` (ketua) dan `member`.
- Anggota hanya dapat membaca tim dan roster yang diikutinya.
- Ringkasan sesi dibagikan eksplisit lewat `team_shared_ride_summaries`;
  menghapus tautan tidak menghapus riwayat pribadi.
- Leaderboard bersifat opt-in, memakai nama profil, dan mendukung rekor
  pribadi (durasi dan jarak terpanjang).
- Perubahan nama profil memperbarui nama anggota tim.

---

## 9. Keamanan dan privasi

Invarian yang harus dijaga:

1. Jangan pernah menaruh `SUPABASE_SERVICE_ROLE_KEY`, `APP_AUTH_JWT_SECRET`,
   `GEMINI_API_KEY`, atau `ANCHOR_PRIVATE_KEY` di Flutter, `.env` klien, test,
   log, atau Git.
2. Jangan mencatat password, token, telemetri mentah, atau isi chat ke log.
3. Semua tabel pengguna wajib RLS; RPC `security definer` wajib memvalidasi
   pemanggil dan menetapkan `search_path = ''`.
4. Sinkronisasi dan anchor wajib memeriksa consent di klien dan server.
5. Telemetri lokal wajib melewati `EncryptedTelemetryCodec`.
6. Access token diverifikasi di Edge Function dengan secret yang sama; jangan
   menerima JWT tanpa verifikasi.
7. Anchor diverifikasi dari RPC publik, bukan dari database Senapath.
8. Hapus data cloud dan lokal harus menghormati status sinkronisasi; jangan
   menghapus salinan lokal yang belum diunggah tanpa peringatan.
9. Data tim hanya terlihat oleh anggota; ringkasan pribadi tidak boleh bocor
   lewat join atau query langsung.
10. Perubahan akun harus membersihkan state sensitif di memori (chat,
    leaderboard, tim, gamifikasi).

Privasi data:

- Telemetri lokal terenkripsi. Saat disinkronkan, telemetri dikirim sebagai
  JSON biasa melalui TLS dan dilindungi RLS; cloud dapat membacanya.
- Foto profil dan kontak darurat disimpan terenkripsi di perangkat.
- Lokasi tidak dikirim ke layanan pihak ketiga untuk iklan.
- Cuaca, angin, dan POI memakai layanan publik (Open-Meteo, Overpass/OSM) dan
  hanya mengirim data yang diperlukan.

---

## 10. Konfigurasi dan menjalankan

### 10.1 Klien

```powershell
flutter pub get
Copy-Item .env.example .env
# isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY
./scripts/flutter_with_env.ps1 run
```

`scripts/flutter_with_env.ps1` membuat `assets/config/client.env` yang hanya
berisi konfigurasi publik. File `.env` tidak dimasukkan ke build.

### 10.2 Backend

```powershell
supabase db push
supabase functions deploy app-auth
supabase functions deploy rider-assistant
supabase functions deploy rider-coach
supabase functions deploy sync-ride-proofs
supabase functions deploy anchor-ride-proofs
```

Secret Edge Function:

```text
APP_AUTH_JWT_SECRET
GEMINI_API_KEY
GEMINI_MODEL
ANCHOR_PRIVATE_KEY
ANCHOR_RPC_URL
ANCHOR_CHAIN_ID
ANCHOR_CHAIN_NAME
ANCHOR_EXPLORER_URL
ANCHOR_PUBLIC_RPC_URL
```

`APP_AUTH_JWT_SECRET` harus sama dengan secret HS256 yang dipercaya project
Supabase. `ANCHOR_RPC_URL` boleh memakai provider dengan API key, sedangkan
`ANCHOR_PUBLIC_RPC_URL` harus dapat diakses klien tanpa rahasia.

### 10.3 Pemeriksaan kualitas

```powershell
dart format lib test
flutter analyze
flutter test
```

Fokus ledger:

```powershell
flutter test test/features/ledger
```

CI menjalankan format, analisis, dan test pada push ke `main` dan pull request.

---

## 11. Pengujian

Test berada di `test/`, mengikuti struktur fitur. Cakupan penting:

- `test/features/session/`: model sesi, codec telemetri, koordinator sync.
- `test/features/ledger/`: blok, repository hash chain, Cubit, verifier anchor.
- `test/features/authentication/`: Cubit akun dan pengaturan biometrik.
- `test/features/leaderboard/`, `teams/`, `gamification/`: aturan sosial.
- `test/features/routes/`: ghost pacer, progres rute, angin, bearing.
- `test/features/logistics/`: model, kurs, format input, zona waktu.
- `test/core/`: validasi, satuan, widget bersama.

Saat mengubah format hash, payload anchor, atau kontrak RPC, perbarui test dan
dokumentasi ini bersamaan. Perubahan yang mengubah skema Drift wajib menaikkan
`schemaVersion` dan menambah langkah migrasi.

---

## 12. Panduan berkontribusi kode

1. Ikuti struktur `domain`/`data`/`presentation`; jangan menambah akses
   Supabase langsung dari widget.
2. Buat dependency lewat constructor dan daftarkan di `main.dart`.
3. Gunakan state immutable dan `copyWith`; jangan mengekspos mutable list.
4. Tangani mode offline secara eksplisit: tampilkan status, jangan gagal diam.
5. Jangan menambah komentar yang mengulang kode. Komentar hanya untuk
   invariant, alasan keamanan, atau format wire yang tidak jelas.
6. Pesan error yang terlihat pengguna memakai bahasa Indonesia yang jelas.
7. Jangan menambah dependency baru tanpa memeriksa lisensi, ukuran, dan
   kompatibilitas platform.
8. Untuk perubahan backend, tambahkan migrasi baru; jangan mengedit migrasi
   yang sudah diterapkan.
9. Untuk perubahan Edge Function, perbarui `_shared` jika kontraknya berubah
   dan deploy ulang semua function terkait.
10. Untuk perubahan ledger/anchor, uji minimal: append idempoten, verifikasi
    rantai, sinkronisasi cloud, anchor berulang, dan verifikasi RPC.

---

## 13. Batasan yang diketahui

- Autentikasi custom tidak memverifikasi kepemilikan email dan tidak memiliki
  pemulihan password.
- Anchor blockchain hanya menyimpan hash head, bukan seluruh data perjalanan.
- Verifikasi anchor bergantung pada ketersediaan RPC publik dan finalitas
  jaringan.
- Telemetri cloud tidak dienkripsi end-to-end; perlindungannya adalah TLS, RLS,
  dan kontrol akses server.
- Fitur cuaca, angin, POI, dan peta membutuhkan layanan eksternal; aplikasi
  tetap dapat merekam perjalanan tanpa layanan tersebut.
- Biometrik hanya membuka sesi tersimpan; jika refresh token dicabut, pengguna
  harus masuk dengan password.
