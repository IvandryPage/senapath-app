# Senapath - Diagram UML (PlantUML)

Dokumen ini berisi diagram PlantUML untuk memahami perilaku dan struktur kode
Senapath. Setiap blok `plantuml` dapat ditempel ke PlantUML editor, ekstensi
PlantUML di VS Code/JetBrains, atau PlantUML Server. Diagram sengaja tidak
menyertakan seluruh kelas UI agar fokus pada domain, data, dan alur penting.

Dokumentasi naratif ada di [CODEBASE.md](CODEBASE.md).

Daftar diagram:

1. Use case - aktor dan fitur utama
2. Activity - siklus hidup perjalanan
3. Activity - sinkronisasi dan anchor bukti perjalanan
4. Class - domain, repository, gateway, dan Cubit inti
5. Sequence - startup dan autentikasi
6. Sequence - merekam dan menyelesaikan perjalanan
7. Sequence - sinkronisasi dan anchor blockchain
8. Sequence - chat AI dan kuota
9. Sequence - bergabung dengan tim

---

## 1. Use case

```plantuml
@startuml
left to right direction
skinparam packageStyle rectangle
skinparam actorStyle awesome

actor "Pesepeda" as Rider
actor "GPS dan sensor" as Sensors
actor "Supabase" as Cloud
actor "Gemini" as Gemini
actor "Sepolia / relayer" as Chain
actor "Open-Meteo / OSM" as Geo

rectangle "Senapath" {
  usecase "Merekam perjalanan" as UC_Record
  usecase "Menjeda dan melanjutkan" as UC_Pause
  usecase "Melihat riwayat dan detail" as UC_History
  usecase "Mengimpor dan mengelola GPX" as UC_Route
  usecase "Mengikuti rute dan navigasi" as UC_Nav
  usecase "Melihat cuaca dan angin" as UC_Weather
  usecase "Mencari fasilitas di sekitar rute" as UC_POI
  usecase "Memakai ghost pacer" as UC_Ghost
  usecase "Latihan interval" as UC_Workout
  usecase "Melihat progres dan level" as UC_Progress
  usecase "Mengelola profil dan kontak darurat" as UC_Profile
  usecase "Melihat dan mengelola tim" as UC_Team
  usecase "Membagikan ringkasan ke tim" as UC_Share
  usecase "Ikut papan peringkat" as UC_Leaderboard
  usecase "Chat dengan asisten AI" as UC_Chat
  usecase "Mendapat rekomendasi latihan" as UC_Coach
  usecase "Mengelola budget dan logistik" as UC_Logistics
  usecase "Mengatur notifikasi" as UC_Notif
  usecase "Daftar, masuk, dan keluar akun" as UC_Auth
  usecase "Sinkronisasi sesi ke cloud" as UC_Sync
  usecase "Membuat bukti perjalanan lokal" as UC_LocalProof
  usecase "Menyinkronkan bukti ke cloud" as UC_CloudProof
  usecase "Mencatat bukti ke blockchain" as UC_Anchor
  usecase "Memverifikasi bukti dari RPC" as UC_Verify
  usecase "Memberi persetujuan" as UC_Consent
  usecase "Menghapus data perjalanan" as UC_Delete
}

Rider --> UC_Record
Rider --> UC_Pause
Rider --> UC_History
Rider --> UC_Route
Rider --> UC_Nav
Rider --> UC_Weather
Rider --> UC_POI
Rider --> UC_Ghost
Rider --> UC_Workout
Rider --> UC_Progress
Rider --> UC_Profile
Rider --> UC_Team
Rider --> UC_Share
Rider --> UC_Leaderboard
Rider --> UC_Chat
Rider --> UC_Coach
Rider --> UC_Logistics
Rider --> UC_Notif
Rider --> UC_Auth
Rider --> UC_Delete

Sensors --> UC_Record
Sensors --> UC_Nav
Geo --> UC_Weather
Geo --> UC_POI
Geo --> UC_Route
Cloud --> UC_Sync
Cloud --> UC_Chat
Cloud --> UC_Team
Cloud --> UC_Leaderboard
Chain --> UC_Anchor
Chain --> UC_Verify
Gemini --> UC_Chat
Gemini --> UC_Coach

UC_Record ..> UC_LocalProof : <<include>>
UC_Record ..> UC_Sync : <<include>>
UC_LocalProof ..> UC_CloudProof : <<extend>>
UC_CloudProof ..> UC_Anchor : <<include>>
UC_Anchor ..> UC_Consent : <<include>>
UC_Anchor ..> UC_Verify : <<include>>
UC_Sync ..> UC_Consent : <<include>>
UC_Leaderboard ..> UC_Consent : <<include>>
UC_Team ..> UC_Share : <<extend>>
UC_Nav ..> UC_Ghost : <<extend>>
UC_Route ..> UC_Weather : <<extend>>
UC_Route ..> UC_POI : <<extend>>
@enduml
```

---

## 2. Activity - siklus hidup perjalanan

```plantuml
@startuml
title Siklus hidup rekaman perjalanan
start

:Membuka aplikasi;
if (Supabase dikonfigurasi?) then (ya)
  if (Sesi akun tersimpan?) then (ya)
    :Pulihkan dan rotasi token;
  else (tidak)
    :Tampilkan layar masuk;
    :Daftar atau masuk;
  endif
else (tidak)
  :Mode lokal tanpa cloud;
endif

:Membuka Beranda;
:Pilih rute atau latihan (opsional);
:Menyiapkan sesi;
:Memeriksa izin lokasi, notifikasi, dan sensor;
if (Perangkat siap?) then (tidak)
  :Tampilkan masalah izin atau sensor;
  stop
endif

:Membuat sesi status recording;
:Menyalakan stream lokasi dan sensor;

repeat
  :Menerima sampel GPS dan sensor;
  :Membungkus TelemetryLocation;
  :Mengenkripsi payload AES-256-GCM;
  :Menyimpan titik ke Drift;
  if (Pengguna menjeda?) then (ya)
    :Menghentikan stream sementara;
    :Menyimpan pausedAt;
    if (Lanjut?) then (ya)
      :Melanjutkan stream;
    else (tidak)
      :Tetap jeda sampai selesai;
    endif
  endif
repeat while (Belum selesai?) is (ya)

:Menghentikan stream;
:Menyelesaikan sesi;
:Menyimpan status completed;

:Tambah blok ke rantai bukti lokal;
:Menyimpan fitur RideHistory untuk prediksi;

if (Auto-sync aktif dan pengguna masuk?) then (ya)
  if (Sesi penuh tersedia?) then (ya)
    :Dorong sesi dan telemetri ke cloud;
  else (tidak)
    :Dorong ringkasan sesi ke cloud;
  endif
else (tidak)
  :Biarkan sesi pending di perangkat;
endif

if (Pengguna membuka riwayat?) then (ya)
  :Tampilkan ringkasan dan detail;
endif

stop
@enduml
```

---

## 3. Activity - sinkronisasi dan anchor bukti

```plantuml
@startuml
title Sinkronisasi dan anchor bukti perjalanan
start

:Pesepeda membuka Bukti perjalanan;
:Pesepeda memilih Catat ke blockchain;
:RideLedgerCubit memuat blok lokal;

if (Hash chain lokal valid?) then (tidak)
  :Tampilkan error integritas;
  stop
endif

:Sinkronkan seluruh blok ke cloud;
if (Sinkronisasi berhasil?) then (tidak)
  :Tampilkan error jaringan atau akun;
  stop
endif

:Server memvalidasi consent dan head cloud;
if (Rate limit tercapai atau head sudah di-anchor?) then (ya)
  :Tampilkan anchor yang ada;
  stop
endif

:Server menyimpan anchor status pending;
:Relayer mengirim transaksi 0 ETH ke Sepolia;
if (Transaksi berhasil dikirim?) then (ya)
  :Server membaca receipt;
  if (Receipt sukses?) then (ya)
    :Status confirmed dan txHash disimpan;
  else (tidak)
    :Status failed;
  endif
else (tidak)
  :Status failed dan error dicatat;
endif

:Pesepeda memilih Verifikasi;
:Klien memanggil RPC publik;
:Klien membaca chain ID, transaksi, dan receipt;
:Klien membandingkan from, calldata, dan head hash;

if (Semua cocok?) then (ya)
  :Tampilkan status verified;
else (tidak)
  if (Transaksi belum masuk blok?) then (ya)
    :Tampilkan status pending;
  else (tidak)
    :Tampilkan status mismatch;
  endif
endif

stop
@enduml
```

---

## 4. Class - inti domain, data, dan presentasi

```plantuml
@startuml
title Kelas inti Senapath
skinparam classAttributeIconSize 0
hide circle

package "core/storage" {
  class AppDatabase {
    +schemaVersion: int
    +appPreferences
    +rideSessions
    +telemetryPoints
    +savedRoutes
    +rideHistory
  }

  interface SecureVault {
    +read(key): String?
    +write(key, value)
    +delete(key)
  }
}

package "features/session" {
  class RideSessionSnapshot {
    +id: String
    +title: String
    +activityType: ActivityType
    +source: String
    +startedAt: DateTime
    +endedAt: DateTime?
    +status: RideSessionStatus
    +syncStatus: String
    +distanceMeters: double
    +gpsAccuracyMeters: double?
    +durationAt(DateTime): Duration
  }

  class TelemetryLocation {
    +recordedAt: DateTime
    +latitude: double
    +longitude: double
    +accuracyMeters: double
    +altitudeMeters: double
    +speedMetersPerSecond: double
  }

  class EncryptedTelemetryCodec {
    +encode(TelemetryLocation): Uint8List
    +decode(Uint8List): TelemetryLocation
    +encryptBytes(List<int>): Uint8List
    +decryptBytes(Uint8List): Uint8List
  }

  interface RideSessionRepository {
    +start(DateTime): RideSessionSnapshot
    +pause(id, DateTime): RideSessionSnapshot
    +resume(id, DateTime): RideSessionSnapshot
    +finish(id, DateTime): RideSessionSnapshot
    +recordLocation(id, TelemetryLocation)
    +loadCompletedSessions()
    +loadSummary(id)
  }

  class DriftRideSessionRepository {
    -database: AppDatabase
    -telemetryCodec: EncryptedTelemetryCodec
  }

  class RideSessionCubit {
    +start(route, workout)
    +pause()
    +resume(route)
    +finish()
    +syncSummary(id, consent)
    +syncCloudSessions()
  }

  class SessionSyncCoordinator {
    +syncSummary(id, consented, teamId)
  }

  interface SessionSyncGateway {
    +isConfigured: bool
    +isSignedIn: bool
    +uploadSummary(summary, teamId)
  }

  class SupabaseSessionSyncGateway

  class RideSessionCloudSync {
    +pullSessions()
    +pushSession(id)
    +deleteSession(id)
  }

  interface AccountCloudGateway {
    +isConfigured: bool
    +isSignedIn: bool
    +pullSetting(key)
    +pushSetting(key, value)
    +pushRideSession(session, points)
    +pullRideSessions()
    +deleteRideSession(id)
  }

  class SupabaseAccountCloudGateway
}

package "features/ledger" {
  class RideLedgerBlock {
    +index: int
    +sessionId: String
    +createdAt: DateTime
    +distanceMeters: double
    +durationSeconds: int
    +previousHash: String
    +hash: String
  }

  class RideLedgerAnchor {
    +id: String
    +blockCount: int
    +headHash: String
    +txHash: String?
    +status: String
    +blockNumber: int?
    +createdAt: DateTime
    +expectedPayload: String
  }

  class RideLedgerChainInfo {
    +chainId: int
    +name: String
    +explorerUrl: String
    +publicRpcUrl: String
    +relayerAddress: String
  }

  class AnchorVerification {
    +status: AnchorVerificationStatus
    +detail: String
  }

  class RideLedgerRepository {
    -database: AppDatabase
    +loadBlocks()
    +appendSession(RideSessionSnapshot)
    +verify(): bool
  }

  interface RideLedgerSyncGateway {
    +isConfigured: bool
    +isSignedIn: bool
    +sync(blocks)
    +anchor()
    +anchors()
  }

  class SupabaseRideLedgerSyncGateway

  class RideLedgerCubit {
    +load()
    +refreshAnchors()
    +verify()
    +sync()
    +anchor()
    +verifyAnchor(RideLedgerAnchor)
  }

  class EvmRpcClient {
    +chainId(): int
    +getTransaction(hash)
    +getReceipt(hash)
  }

  class RideLedgerAnchorVerifier {
    +verify(anchor, chain, localBlocks, rpc)
  }
}

package "features/authentication" {
  class CustomAuthSessionManager {
    +currentUserId: String?
    +requireAccessToken()
    +invokeAuthenticatedFunction(name, body)
    +signIn(email, password)
    +signOut()
  }

  class CloudAccountCubit {
    +initialize()
    +signIn(email, password)
    +signUp(email, password)
    +signOut()
  }

  interface CloudAccountGateway {
    +isConfigured: bool
    +isSignedIn: bool
    +signIn(email, password)
    +signUp(email, password)
    +signOut()
  }

  class SupabaseCloudAccountGateway
}

package "fitur cloud lain" {
  class AiChatCubit
  class SupabaseAiChatGateway
  class CyclingTeamCubit
  class SupabaseCyclingTeamRepository
  class LeaderboardCubit
  class SupabaseLeaderboardGateway
}

RideSessionCubit --> RideSessionRepository
RideSessionCubit --> RideLedgerRepository
RideSessionCubit --> SessionSyncCoordinator
RideSessionCubit --> RideSessionCloudSync
DriftRideSessionRepository ..|> RideSessionRepository
DriftRideSessionRepository --> AppDatabase
DriftRideSessionRepository --> EncryptedTelemetryCodec
EncryptedTelemetryCodec --> SecureVault
SessionSyncCoordinator --> RideSessionRepository
SessionSyncCoordinator --> SessionSyncGateway
SupabaseSessionSyncGateway ..|> SessionSyncGateway
SupabaseSessionSyncGateway --> CustomAuthSessionManager
RideSessionCloudSync --> RideSessionRepository
RideSessionCloudSync --> AccountCloudGateway
SupabaseAccountCloudGateway ..|> AccountCloudGateway
SupabaseAccountCloudGateway --> CustomAuthSessionManager

RideLedgerRepository --> AppDatabase
RideLedgerCubit --> RideLedgerRepository
RideLedgerCubit --> RideLedgerSyncGateway
RideLedgerCubit --> RideLedgerAnchorVerifier
RideLedgerCubit ..> EvmRpcClient : membuat saat verifikasi
RideLedgerAnchorVerifier --> EvmRpcClient
RideLedgerAnchorVerifier ..> RideLedgerBlock
RideLedgerAnchorVerifier ..> RideLedgerAnchor
SupabaseRideLedgerSyncGateway ..|> RideLedgerSyncGateway
SupabaseRideLedgerSyncGateway --> CustomAuthSessionManager

CloudAccountCubit --> CloudAccountGateway
SupabaseCloudAccountGateway ..|> CloudAccountGateway
SupabaseCloudAccountGateway --> CustomAuthSessionManager
CustomAuthSessionManager --> SecureVault

AiChatCubit --> SupabaseAiChatGateway
CyclingTeamCubit --> SupabaseCyclingTeamRepository
LeaderboardCubit --> SupabaseLeaderboardGateway
SupabaseAiChatGateway --> CustomAuthSessionManager
SupabaseCyclingTeamRepository --> CustomAuthSessionManager
SupabaseLeaderboardGateway --> CustomAuthSessionManager

note bottom of RideLedgerRepository
  Hash chain disimpan di AppPreferences
  dengan key ride_proof_chain_v1.
end note

note bottom of CustomAuthSessionManager
  Menyimpan token di SecureVault dan
  memverifikasi JWT lewat Edge Function.
end note
@enduml
```

---

## 5. Sequence - startup dan autentikasi

```plantuml
@startuml
title Startup dan login custom
autonumber

actor "Pesepeda" as User
participant "CloudAccountScreen" as UI
participant "CloudAccountCubit" as Cubit
participant "SupabaseCloudAccountGateway" as Gateway
participant "CustomAuthSessionManager" as Session
participant "app-auth" as Fn
participant "Postgres" as DB
participant "SecureVault" as Vault

User -> UI : Membuka aplikasi
UI -> Cubit : initialize()
Cubit -> Gateway : restoreSession()
Gateway -> Session : restore dari secure storage
Session -> Vault : baca token
Vault --> Session : token atau null

alt Sesi tersedia
  Session -> Fn : action=refresh, refreshToken
  Fn -> DB : rotate_app_auth_session()
  DB --> Fn : sesi baru
  Fn --> Session : access JWT + refresh token baru
  Session -> Vault : simpan token baru
  Session --> Cubit : signedIn
  Cubit -> Cubit : muat data akun
else Belum punya sesi
  Cubit --> UI : tampilkan form masuk
  User -> UI : email dan password
  UI -> Cubit : signIn(email, password)
  Cubit -> Gateway : signIn(email, password)
  Gateway -> Session : signIn()
  Session -> Fn : action=sign-in
  Fn -> DB : baca app_users + rate limit
  Fn -> Fn : verifikasi PBKDF2-SHA256
  alt Kredensial valid
    Fn -> DB : buat/rotasi sesi refresh
    DB --> Fn : refresh token hash
    Fn --> Session : access JWT + refresh token
    Session -> Vault : simpan token
    Session --> Cubit : signedIn
    Cubit --> UI : buka Beranda
  else Kredensial salah
    Fn --> Session : HTTP 401
    Session --> Cubit : error
    Cubit --> UI : tampilkan pesan
  end
end

Cubit -> Cubit : reset state akun lama
Cubit -> Cubit : muat leaderboard, tim, profil, sesi
@enduml
```

---

## 6. Sequence - merekam dan menyelesaikan perjalanan

```plantuml
@startuml
title Merekam perjalanan
autonumber

actor "Pesepeda" as User
participant "SessionScreen" as UI
participant "RideSessionCubit" as Cubit
participant "GPS dan sensor" as Sensors
participant "DriftRideSessionRepository" as Repo
participant "EncryptedTelemetryCodec" as Codec
participant "AppDatabase" as DB
participant "RideLedgerRepository" as Ledger
participant "RideHistoryRepository" as History
participant "SessionSyncCoordinator" as Sync
participant "Supabase" as Cloud

User -> UI : Pilih mulai
UI -> Cubit : start(route, workout)
Cubit -> Cubit : periksa izin dan readiness
Cubit -> Repo : start(now)
Repo -> DB : insert RideSessions status=recording
DB --> Repo : sesi
Repo --> Cubit : RideSessionSnapshot
Cubit -> Sensors : berlangganan lokasi, barometer, gerak
Sensors --> Cubit : sampel sensor

loop Selama merekam
  Sensors --> Cubit : TelemetryLocation
  Cubit -> Repo : recordLocation(id, point)
  Repo -> Codec : encode(point)
  Codec --> Repo : ciphertext AES-GCM
  Repo -> DB : insert TelemetryPoints
  Cubit -> UI : perbarui jarak, kecepatan, elevasi
end

alt Pengguna menjeda
  User -> UI : Jeda
  UI -> Cubit : pause()
  Cubit -> Sensors : hentikan stream
  Cubit -> Repo : pause(id, now)
  Repo -> DB : update pausedAt dan status
else Pengguna melanjutkan
  User -> UI : Lanjut
  UI -> Cubit : resume(route)
  Cubit -> Repo : resume(id, now)
  Cubit -> Sensors : mulai stream lagi
end

User -> UI : Selesai
UI -> Cubit : finish()
Cubit -> Sensors : hentikan semua stream
Cubit -> Repo : finish(id, now)
Repo -> DB : update endedAt, distance, status=completed
DB --> Repo : sesi selesai
Repo --> Cubit : RideSessionSnapshot

Cubit -> Ledger : appendSession(session)
Ledger -> Ledger : hitung hash dan previousHash
Ledger -> DB : simpan ride_proof_chain_v1
Ledger --> Cubit : blok ditambahkan

Cubit -> History : recordCompletedRide(session)
History -> DB : insert RideHistory
History --> Cubit : selesai

opt Auto-sync aktif dan pengguna masuk
  Cubit -> Sync : syncSummary(id, consented=true)
  Sync -> Cloud : unggah ringkasan
  Cloud --> Sync : tersimpan
  Sync --> Cubit : status synced
end

Cubit --> UI : tampilkan ringkasan selesai
@enduml
```

---

## 7. Sequence - sinkronisasi dan anchor blockchain

```plantuml
@startuml
title Anchor bukti perjalanan ke Sepolia
autonumber

actor "Pesepeda" as User
participant "RideLedgerScreen" as UI
participant "RideLedgerCubit" as Cubit
participant "RideLedgerRepository" as Repo
participant "SupabaseRideLedgerSyncGateway" as Gateway
participant "sync-ride-proofs" as SyncFn
participant "Postgres" as DB
participant "anchor-ride-proofs" as AnchorFn
participant "Relayer" as Relayer
participant "Sepolia RPC" as Chain
participant "EvmRpcClient" as Rpc
participant "RideLedgerAnchorVerifier" as Verifier

User -> UI : Buka Bukti perjalanan
UI -> Cubit : load()
Cubit -> Repo : loadBlocks()
Repo --> Cubit : blok lokal
Cubit -> Repo : verify()
Repo --> Cubit : valid atau tidak
Cubit --> UI : tampilkan rantai dan anchor

User -> UI : Catat ke blockchain
UI -> Cubit : anchor()
Cubit -> Repo : loadBlocks()
Cubit -> Gateway : sync(blocks)
Gateway -> SyncFn : POST consent=true, blocks
SyncFn -> DB : append_my_ride_proof_blocks()
DB --> SyncFn : blockCount dan head
SyncFn --> Gateway : cloudSynced=true
Gateway --> Cubit : RideLedgerSyncResult

Cubit -> Gateway : anchor()
Gateway -> AnchorFn : POST action=anchor, consent=true
AnchorFn -> DB : reserve_ride_proof_anchor()
alt Ditolak karena rate limit atau head sama
  DB --> AnchorFn : error atau anchor lama
  AnchorFn --> Gateway : daftar anchor
  Gateway --> Cubit : anchor lama
  Cubit --> UI : tampilkan pesan
else Reservasi berhasil
  DB --> AnchorFn : anchor_id, head, block_count
  AnchorFn -> AnchorFn : build payload senapath:v1
  AnchorFn -> Relayer : kirim transaksi 0 ETH
  Relayer -> Chain : eth_sendRawTransaction
  Chain --> Relayer : txHash
  Relayer --> AnchorFn : txHash
  AnchorFn -> DB : status pending + txHash
  AnchorFn -> Chain : baca receipt
  alt Receipt sukses
    AnchorFn -> DB : status confirmed + blockNumber
  else Receipt gagal
    AnchorFn -> DB : status failed
  end
  AnchorFn --> Gateway : daftar anchor terbaru
  Gateway --> Cubit : anchors
  Cubit --> UI : status anchor
end

User -> UI : Verifikasi anchor
UI -> Cubit : verifyAnchor(anchor)
Cubit -> Rpc : chainId()
Rpc --> Cubit : chain ID
Cubit -> Verifier : verify(anchor, chain, localBlocks, rpc)
Verifier -> Rpc : getTransaction(txHash)
Rpc --> Verifier : transaksi
Verifier -> Rpc : getReceipt(txHash)
Rpc --> Verifier : receipt
Verifier -> Verifier : cek chain, from, calldata, head hash
Verifier --> Cubit : AnchorVerification
Cubit --> UI : verified, pending, atau mismatch
@enduml
```

---

## 8. Sequence - chat AI dan kuota

```plantuml
@startuml
title Chat AI dengan kuota harian
autonumber

actor "Pesepeda" as User
participant "AiChatScreen" as UI
participant "AiChatCubit" as Cubit
participant "SupabaseAiChatGateway" as Gateway
participant "CustomAuthSessionManager" as Session
participant "rider-assistant" as Fn
participant "Postgres" as DB
participant "Gemini" as Gemini

User -> UI : Kirim pertanyaan
UI -> Cubit : sendMessage(text)
Cubit -> Cubit : tambah pesan pengguna
Cubit -> Gateway : send(messages)
Gateway -> Session : requireAccessToken()
Session --> Gateway : access JWT
Gateway -> Fn : POST messages + Authorization
Fn -> Session : verifikasi JWT
Session --> Fn : user id
Fn -> DB : consume_ai_chat_quota(userId)
DB --> Fn : true atau false

alt Kuota habis
  Fn --> Gateway : HTTP 429
  Gateway --> Cubit : error kuota
  Cubit --> UI : tampilkan pesan
else Kuota tersedia
  Fn -> Gemini : generateContent(messages)
  alt Gemini sukses
    Gemini --> Fn : teks jawaban
    Fn --> Gateway : jawaban
    Gateway --> Cubit : teks
    Cubit -> Cubit : tambah pesan asisten
    Cubit --> UI : tampilkan jawaban
  else Gemini gagal
    Gemini --> Fn : error 4xx/5xx
    Fn --> Gateway : pesan error
    Gateway --> Cubit : error
    Cubit --> UI : tampilkan pesan
  end
end

opt Ganti akun
  Cubit -> Cubit : clearConversation()
end
@enduml
```

Catatan: kuota diperiksa sebelum panggilan Gemini. Jika Gemini gagal setelah
kuota terpakai, perilaku pengembalian kuota ditentukan oleh implementasi
`consume_ai_chat_quota`; lihat migrasi `20261001000000_ai_chat_quota.sql`.

---

## 9. Sequence - bergabung dengan tim

```plantuml
@startuml
title Bergabung dan berbagi ringkasan tim
autonumber

actor "Pesepeda" as User
participant "CyclingTeamScreen" as UI
participant "CyclingTeamCubit" as Cubit
participant "SupabaseCyclingTeamRepository" as Repo
participant "CustomAuthSessionManager" as Session
participant "Postgres" as DB

User -> UI : Masukkan kode undangan
UI -> Cubit : joinTeam(inviteCode)
Cubit -> Repo : join(inviteCode)
Repo -> Session : requireAccessToken()
Session --> Repo : access JWT
Repo -> DB : RPC join_cycling_team(inviteCode)
DB -> DB : validasi kode 32 hex
DB -> DB : insert cycling_team_members
DB --> Repo : tim dan peran
Repo --> Cubit : CyclingTeam
Cubit --> UI : dashboard tim

User -> UI : Bagikan sesi
UI -> Cubit : shareSummary(sessionId)
Cubit -> Repo : shareRide(teamId, sessionId)
Repo -> DB : insert team_shared_ride_summaries
DB --> Repo : tautan tersimpan
Repo --> Cubit : sukses
Cubit --> UI : ringkasan tampil untuk anggota

alt Anggota keluar
  User -> UI : Keluar dari tim
  UI -> Cubit : leaveTeam(teamId)
  Cubit -> Repo : leave(teamId)
  Repo -> DB : RPC leave_cycling_team()
  DB -> DB : hapus keanggotaan atau tolak jika ketua
  DB --> Repo : hasil
else Ketua menghapus tim
  User -> UI : Hapus tim
  UI -> Cubit : deleteTeam(teamId)
  Cubit -> Repo : delete(teamId)
  Repo -> DB : RPC delete_cycling_team()
  DB -> DB : hapus tim dan tautan ringkasan
  DB --> Repo : hasil
end
@enduml
```

---

## Cara merender

- VS Code: pasang ekstensi `PlantUML` (jebbs), buka preview pada blok diagram.
- JetBrains: pasang plugin PlantUML.
- CLI: ekstrak satu blok ke file `.puml`, lalu jalankan
  `java -jar plantuml.jar diagram.puml`.
- Online: tempel isi blok `@startuml ... @enduml` ke PlantUML Server.

Jika diagram diubah, jaga agar nama kelas dan method tetap sesuai dengan kode di
`lib/`. Diagram ini adalah dokumentasi arsitektur, bukan pengganti test.
