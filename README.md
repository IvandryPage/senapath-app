# Senapath

Aplikasi pendamping latihan dan balapan sepeda.

## Menjalankan aplikasi

```sh
flutter pub get
Copy-Item .env.example .env
./scripts/flutter_with_env.ps1 run
```

Jalankan `Copy-Item` hanya saat `.env` belum ada agar konfigurasi lokal tidak tertimpa. Isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` di `.env`. Keduanya konfigurasi klien yang dapat diekstrak dari aplikasi. `.env` diabaikan Git. Jangan masukkan password pengguna, signing secret JWT, service-role key, atau Gemini API key ke Flutter.

## Pemeriksaan kualitas

Isi konfigurasi klien di `.env` lokal. Runner membuat asset `assets/config/client.env` yang hanya memuat URL dan publishable key; `.env` sumber tidak pernah dimasukkan ke APK. Signing secret JWT, Resend key, service-role key, dan Gemini key hanya dipakai Supabase Edge Functions.
dart format lib test
flutter analyze
flutter test

````

GitHub Actions menjalankan pemeriksaan format, analisis statis, dan widget tests pada push ke `main` serta pull request.

## Autentikasi custom Senapath

Layar **Akun online** memakai endpoint custom `app-auth`, bukan Supabase Auth. Hanya pendaftaran/login email-password yang tersedia. Password diverifikasi server-side dan disimpan hanya sebagai PBKDF2-HMAC-SHA256 hash dengan salt acak, bukan plaintext atau ciphertext yang dapat didekripsi.

Pendaftaran langsung membuat sesi; verifikasi email dan Resend tidak diperlukan untuk daftar atau login. Alamat email tidak diverifikasi kepemilikannya, jadi salah ketik dapat membuat akun yang tidak bisa dipulihkan. Fitur lupa password hanya berfungsi bila provider email recovery dikonfigurasi.

1. Pastikan project Supabase mengizinkan custom HS256 JWT dengan secret yang sama dengan `APP_AUTH_JWT_SECRET`. Token menggunakan `role=authenticated`, `aud=authenticated`, dan `sub=<app_users.id>` agar policy `auth.uid()` berlaku. Jangan gunakan sembarang secret yang tidak dipercaya API project. Project yang hanya menerima asymmetric signing keys perlu signer yang cocok.
2. Atur secret Edge Function `APP_AUTH_JWT_SECRET`. Jangan pernah memasukkan nilai ini ke aplikasi atau Git:

   ```sh
   supabase secrets set APP_AUTH_JWT_SECRET="<signing secret yang sama dengan Supabase API>"
   ```

   `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` disediakan otomatis untuk Supabase Edge Functions. Untuk mengaktifkan lupa password saja, tambahkan `RESEND_API_KEY`, `AUTH_EMAIL_FROM`, dan `AUTH_PASSWORD_RESET_URL`.
3. Terapkan semua migrasi (termasuk migrasi auth yang menghapus tabel verifikasi email yang tidak dipakai dan membuat pendaftaran+sesi atomik), lalu deploy function:

   ```sh
   supabase db push
   supabase functions deploy app-auth
   ```

4. Pastikan `.env` aplikasi berisi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`, lalu rebuild/restart aplikasi. Tes daftar email; jika secret backend belum lengkap, aplikasi menampilkan konfigurasi yang perlu diatur.

Jika pendaftaran gagal, periksa pesan error yang tampil terlebih dahulu. Error skema meminta migrasi dijalankan dengan `supabase db push` dan function di-deploy ulang. Untuk error lain, buka **Supabase Dashboard → Edge Functions → app-auth → Logs** dan cari reference ID yang ditampilkan aplikasi. Pastikan URL/publishable key aplikasi mengarah ke project yang sama, `APP_AUTH_JWT_SECRET` sudah disetel, dan migration history menunjukkan semua migrasi selesai.

Migrasi mempertahankan UUID akun lama dari `auth.users`, tetapi password Supabase Auth tidak dapat dipakai oleh custom auth. Akun lama yang belum memiliki password custom tidak dapat diklaim melalui daftar tanpa verifikasi kepemilikan; hubungi operator untuk migrasi aman. Ini sengaja mencegah orang lain mengambil alih data lama hanya dengan mengetik alamat email yang sama.

Di **Profil → Akun online**, pengguna dapat mendaftar/masuk dengan email dan password, meminta reset password, serta keluar dari akun cloud. Password dikirim via HTTPS ke Edge Function; token sesi disimpan di secure storage dan refresh token selalu dirotasi. Setelah pernah login, sesi tersimpan dapat dipulihkan dari layar akun memakai biometrik perangkat—password tidak disimpan, dan biometrik bukan gerbang unlock seluruh aplikasi. Login biometrik hanya tersedia jika sesi masih tersimpan; logout cloud mencabut sesi itu. Reset password menampilkan konfirmasi generik agar keberadaan suatu email tidak diungkapkan. Keluar dari akun cloud mempertahankan data lokal.

## Tema tampilan

Pilih **Sistem**, **Terang**, atau **Gelap** di bagian **Profil → Tema tampilan**. Pilihan disimpan di preferensi lokal Drift dan diterapkan ke seluruh aplikasi. Mode Sistem mengikuti pengaturan tampilan perangkat.

## Rute GPX dan panduan offline

1. Buka tab **Jelajah** untuk melihat basemap OpenStreetMap; peta tetap tampil meskipun belum ada rute tersimpan.
2. Pilih tombol **Impor GPX**.
3. Pilih berkas GPX yang berisi minimal dua titik track.
4. Ketuk rute yang tersimpan untuk melihat bentuk jalur, jarak, dan elevasi yang tersedia.
5. Pilih **Ikuti rute** untuk melihat jalur bersama posisi GPS, progres, jarak tersisa, dan peringatan bila fix GPS akurat menunjukkan kamu keluar jalur.

Beranda dan tab Jelajah menampilkan basemap OpenStreetMap online, dengan jalur GPX dan posisi GPS di atasnya jika tersedia. Tombol lokasi meminta izin hanya saat digunakan; tanpa izin, peta tetap dapat digeser dan diperbesar di sekitar Yogyakarta. Tile peta dimuat online dan tidak tersedia offline; file GPX tetap tersimpan lokal dan jalurnya tetap ditampilkan saat basemap gagal dimuat atau perangkat offline. Peta menyediakan status tile dan tombol muat ulang, serta atribusi OpenStreetMap. Izin lokasi dan layanan GPS perangkat diperlukan untuk posisi langsung.

### Pencarian rute sepeda Google Maps

Di **Jelajah**, ketik nama tempat/alamat lalu tekan cari. Aplikasi meminta izin dan posisi GPS sebagai titik awal; Supabase Edge Function `cycling-route` memanggil Google Directions API dengan mode bersepeda. Rute online divisualisasikan di Google Maps SDK, sedangkan GPX lokal tetap menggunakan OpenStreetMap. Rute online hanya sementara, tidak disimpan sebagai GPX, dan tidak menyediakan navigasi belokan demi belokan.

Ada **dua konfigurasi Google yang terpisah**:

| Kebutuhan | Lokasi pemakaian | API key |
| --- | --- | --- |
| Menghitung rute bersepeda | Supabase Edge Function `cycling-route` | Server-side Directions API key |
| Menampilkan basemap Google untuk rute hasil pencarian | Aplikasi Android/iOS | SDK key yang dibatasi per platform |

Jangan gunakan atau salin server-side key ke aplikasi. API key Android/iOS dikemas di aplikasi dan dapat diekstrak, jadi pembatasan key di Google Cloud wajib dilakukan.
Jika sebuah key pernah dibagikan lewat chat, screenshot, log, atau commit, cabut key tersebut di Google Cloud dan buat pengganti sebelum digunakan.

#### A. Siapkan Google Cloud

1. Pilih atau buat Google Cloud project dan tautkan akun billing yang aktif.
2. Buka **APIs & Services → Library**, aktifkan **Directions API** serta **Maps SDK for Android** dan/atau **Maps SDK for iOS** sesuai target. Search menggunakan Directions API di server; SDK Android/iOS hanya merender peta.
3. Buka **APIs & Services → Credentials** dan buat key yang berbeda:
   - **Server Directions key:** batasi API key ke Directions API. Jika Google Cloud mendukung application restriction untuk server deployment-mu, batasi juga sesuai lingkungan server; jangan menanam key ini dalam app.
   - **Android Maps SDK key:** batasi application restriction ke Android apps, dengan package ID `com.example.senapath` dan SHA-1 certificate yang benar untuk build yang diuji. Batasi API key ke Maps SDK for Android.
   - **iOS Maps SDK key:** batasi application restriction ke iOS apps dengan bundle ID dari Xcode project, dan batasi API key ke Maps SDK for iOS.
4. Mulai dengan batas kuota/budget dan alert billing yang sesuai. Restriction API, application, serta billing harus cocok dengan konfigurasi aktual; nama API yang tidak aktif atau key yang dibatasi untuk platform/key yang salah dapat menghasilkan `REQUEST_DENIED`.

#### B. Siapkan Supabase backend

1. Pastikan project Supabase terhubung ke direktori `supabase` repository:

   ```sh
   supabase login
   supabase link --project-ref "<project-ref>"
   ```

2. Siapkan custom authentication lebih dahulu sesuai bagian **Autentikasi custom Senapath**. Secara khusus, `APP_AUTH_JWT_SECRET` harus sama dengan secret HS256 yang dipercaya konfigurasi JWT project Supabase. Function mengharapkan custom JWT Senapath; publishable/anon key saja bukan sesi pengguna.
3. Set server Directions key sebagai Edge Function secret, lalu deploy function:

   ```sh
   supabase secrets set GOOGLE_MAPS_API_KEY="<server-side Directions API key>"
   supabase functions deploy cycling-route
   ```

   Jangan set SDK key sebagai `GOOGLE_MAPS_API_KEY` server. Edge Function memeriksa custom JWT, membatasi akun hingga 30 pencarian per hari, dan tidak menyimpan geometri Google. `SUPABASE_URL` serta `SUPABASE_SERVICE_ROLE_KEY` tersedia untuk Edge Functions dari konfigurasi project Supabase; jangan memasukkan service-role key ke aplikasi.
4. Setelah secret diganti, deploy ulang function seperti di atas dan periksa log function di Supabase Dashboard bila request masih gagal. Jangan menaruh server key, signing secret, atau service-role key di `.env` aplikasi, asset Flutter, Git, screenshot, atau chat.

#### C. Siapkan aplikasi lokal

1. Isi `.env` lokal hanya dengan konfigurasi client Supabase yang memang dibutuhkan runner:

   ```dotenv
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_PUBLISHABLE_KEY=<publishable-key>
   ```

   `scripts/flutter_with_env.ps1` hanya menyalin dua nilai ini ke asset client Flutter. **Jangan** menambahkan `GOOGLE_MAPS_API_KEY`, `APP_AUTH_JWT_SECRET`, service-role key, atau password pengguna ke file tersebut.
2. Untuk Android, tambahkan baris berikut ke `android/local.properties` (file lokal, jangan commit), atau sediakan environment variable saat build:

   ```properties
   GOOGLE_MAPS_API_KEY=<Android Maps SDK key>
   ```

   Gradle membaca environment variable `GOOGLE_MAPS_API_KEY` lebih dahulu, lalu `android/local.properties`.
3. Untuk iOS, buat `ios/Flutter/Local.xcconfig` yang diabaikan Git dan isi:

   ```xcconfig
   GOOGLE_MAPS_API_KEY = <iOS Maps SDK key>
   ```

   `Debug.xcconfig` dan `Release.xcconfig` memuat file ini secara opsional. Pastikan bundle ID di restriction Google cocok dengan target Xcode.
4. Jalankan aplikasi melalui script agar konfigurasi client Supabase disiapkan:

   ```powershell
   .\scripts\flutter_with_env.ps1 run
   ```

   Jika menggunakan Android/iOS SDK key baru, hentikan aplikasi lalu build dan jalankan ulang; hot reload tidak memperbarui native manifest/config.
5. Di aplikasi, masuk melalui **Profil → Akun online**, izinkan lokasi, aktifkan layanan lokasi, lalu coba tujuan yang valid seperti nama tempat umum di area dengan cakupan rute sepeda Google Maps.

#### Diagnosis cepat

- **Pencarian rute belum dikonfigurasi di backend:** client Supabase tidak termuat, `cycling-route` belum ter-deploy, atau `RoutesCubit` belum menerima planner. Jalankan melalui script di atas dan pastikan deploy ke project Supabase yang sama dengan `SUPABASE_URL`.
- **Masuk ke akun online / sesi tidak valid (401/403):** login ulang, periksa konfigurasi custom JWT (`APP_AUTH_JWT_SECRET` dan JWT signing project), serta deploy function dengan konfigurasi `verify_jwt` repository.
- **Layanan rute belum dikonfigurasi (503):** periksa `GOOGLE_MAPS_API_KEY` dan Supabase secrets backend, lalu deploy ulang function. Jangan mencari secret ini dalam asset app.
- **Google Maps ditolak (`REQUEST_DENIED`):** verifikasi billing, Directions API enablement, key yang dipakai server, dan restriction API key. Periksa Supabase Function logs untuk status Google tanpa menyalin/menampilkan nilai key.
- **Peta Google kosong atau bertuliskan `For development purposes only`:** ini masalah Maps SDK key pada platform, bukan pencarian Directions. Periksa restriction package ID + SHA-1 Android atau bundle ID iOS, Maps SDK yang diaktifkan, billing, lalu rebuild native app.
- **Lokasi atau titik awal gagal:** izinkan lokasi dan aktifkan layanan lokasi perangkat; endpoint ini memakai posisi GPS perangkat sebagai origin.
- **Rute tidak ditemukan / ZERO_RESULTS:** coba tujuan lain. Coverage rute bersepeda bergantung pada data Google untuk area tersebut; function tidak membuat rute garis lurus sebagai fallback.
- **HTTP 429:** akun telah mencapai batas 30 pencarian dalam 24 jam.

Tanpa Directions key dan konfigurasi backend, pencarian rute tidak aktif. Tanpa SDK key platform, Google basemap untuk rute hasil pencarian tidak akan tampil dengan benar. Impor GPX lokal/OpenStreetMap tetap dapat digunakan secara terpisah.

Beranda memakai pola feed aktivitas: ringkasan jarak/sesi tujuh hari terakhir, aktivitas terbaru, peta, dan pintasan fitur dalam kartu. Tab profil dan jelajah dapat dibuka langsung dari dashboard.

Impor GPX menerima file hingga 10 MB, memvalidasi titik track, dan mempertahankan nama/deskripsi yang tersedia. Jarak dan elevasi mengikuti sistem satuan yang dipilih di Profil. Bagian **Profil → Penyimpanan offline** menampilkan ukuran database dan direktori cache peta serta dapat menghapus cache peta tanpa menghapus sesi atau rute.

Pemeriksaan pra-balapan menampilkan status izin notifikasi. Jika belum diberikan, pengguna dapat meminta izin OS dari layar tersebut atau membuka pengaturan perangkat bila izin pernah ditolak permanen. Ini hanya meminta izin; pengingat hidrasi dan peringatan cuaca/rute terjadwal belum tersedia.

Integrasi menggunakan layanan tile publik OpenStreetMap untuk penggunaan ringan. Jangan melakukan prefetch/download tile atau mengandalkan layanan publik ini untuk trafik produksi berskala besar; evaluasi provider tile yang sesuai dengan kebutuhan, lisensi, dan kebijakan penggunaan sebelum rilis publik.

## Konversi zona waktu dunia

Di tab **Logistik → Waktu acara**, pilih tanggal/waktu dan tekan zona waktu sumber untuk mencari kota atau zona IANA, misalnya `America/New_York`. Tambahkan satu atau lebih zona tujuan melalui **Tambah zona**. Aturan DST dan pergantian tanggal ditangani oleh database zona waktu yang dibundel; jam lokal yang tidak ada atau ambigu meminta pengguna memilih waktu/kemunculan yang valid.

## Tantangan strategi rute

Di **Beranda → Strategi rute**, pemain menjawab tiga skenario edukatif seputar tempo, kondisi rute, dan persiapan balapan. Tantangan tidak memakai timer, disimpan lokal di perangkat, dan dinonaktifkan ketika sesi perjalanan sedang merekam atau dijeda. Ini bukan instruksi balap real-time atau evaluasi AI.

## Papan peringkat mingguan

Peringkat tersedia melalui **Beranda → Papan peringkat** dan hanya dapat dilihat setelah masuk akun online serta mengaktifkan partisipasi dengan alias publik. Pilih **Papan peringkat** dari ringkasan sesi selesai untuk mengirim nilainya; ringkasan itu harus lebih dahulu disinkronkan secara terpisah. Minggu berjalan dihitung Senin–Minggu UTC, dengan kategori durasi aktif terlama dan jarak terjauh dari satu sesi. Peringkat hanya menampilkan urutan, alias, dan skor. Skor bersumber dari ringkasan yang dilaporkan aplikasi, belum diverifikasi independen. Opt-out menghapus seluruh skor akun dari tabel peringkat. Terapkan migrasi terbaru dengan `supabase db push`.

## Sinkronisasi ringkasan sesi

Sinkronisasi memerlukan login online dan migrasi Supabase terbaru:

```sh
supabase db push
```

Setelah sesi selesai, buka ringkasannya lalu pilih **Sinkronkan ringkasan** dan setujui pengiriman. Hanya waktu mulai/selesai, durasi, jarak, jumlah sampel, informasi elevasi, dan jumlah sampel sensor yang dikirim ke `ride_session_summaries`; koordinat GPS, geometri rute, dan telemetri mentah tidak dikirim. Status lokal menjadi tersinkron hanya setelah upsert server berhasil. Kunci idempotensi gabungan `user_id, session_id` mencegah retry membuat duplikat, RLS membatasi akses per akun, dan penghapusan akun menghapus ringkasan cloud melalui foreign key cascade.

## Chat AI (Supabase + Gemini)

Chat hanya mengirim pesan setelah pengguna menyetujui. Rute lokal dan preferensi latihan hanya disertakan bila dipilih. Percakapan tidak disimpan di riwayat lokal; permintaan diteruskan melalui Supabase ke Google Gemini. Jangan masukkan kontak darurat atau informasi sensitif.

1. Buat proyek Supabase. Supabase Auth email provider tidak digunakan untuk daftar/login custom ini. Atur provider email hanya jika ingin mengaktifkan lupa password; redirect reset harus mengarah ke aplikasi.
2. Login dan tautkan proyek lokal sebelum menerapkan migrasi:

```sh
supabase login
supabase link --project-ref your-project-ref
```

3. Terapkan migrasi kuota harian, atur secret Gemini hanya di Supabase, lalu deploy function:

```sh
supabase db push
supabase secrets set GEMINI_API_KEY=your-gemini-api-key
# Optional; defaults to gemini-2.5-flash
supabase secrets set GEMINI_MODEL=gemini-2.5-flash
supabase functions deploy rider-assistant
supabase functions deploy submit-feedback
```

Untuk menjalankan Edge Function secara lokal, isi `GEMINI_API_KEY` di `.env` lalu gunakan `supabase functions serve --env-file .env`; Supabase CLI menyediakan variabel Supabase lokal bagi function. Saat deploy, masukkan Gemini key ke Supabase Secrets seperti perintah di atas. Jangan simpan `SUPABASE_SERVICE_ROLE_KEY` di Flutter atau commit ke repo.

Jika chat tidak mendapat jawaban, pastikan akun online sudah masuk, migrasi kuota sudah diterapkan, lalu cek nama secrets tanpa menampilkan nilainya dan lihat log function:

```sh
supabase secrets list
supabase functions logs rider-assistant --project-ref your-project-ref
```

Error sesi berarti login ulang diperlukan; error konfigurasi berarti periksa `GEMINI_API_KEY`, `GEMINI_MODEL`, dan function yang ter-deploy; error kuota harian tidak akan hilang dengan mengirim ulang pesan.

4. Jalankan aplikasi dengan URL proyek dan publishable key Supabase dari `.env`:

```sh
.\scripts\flutter_with_env.ps1 build apk --release
```

Publishable key memang digunakan oleh aplikasi klien; jangan pernah memasukkan signing secret JWT, service-role key, Resend key, atau Gemini API key ke runner Flutter. Password dikelola server-side oleh custom auth dan tidak disimpan oleh aplikasi. Function AI membatasi setiap akun aplikasi hingga 30 permintaan per hari. Feedback terkirim disimpan di tabel `user_feedback` untuk ditinjau tim; hapus data secara berkala sesuai kebijakan retensi proyek. Atur kuota dan batas biaya Gemini di Google AI Studio/Google Cloud. Chat dan feedback memerlukan sesi akun online. Password reset email opsional memerlukan provider email dan secrets Edge Function sesuai bagian autentikasi.
