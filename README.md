# Senapath

Aplikasi pendamping latihan dan balapan sepeda.

> **Tujuan besar:** Senapath adalah "Strava untuk cyclist" — rumah digital untuk merekam ride, merencanakan rute, berlatih, dan terhubung dengan komunitas cyclist, dengan tumpukan gratis/OSS dan etika data yang kuat. Lihat [agents/vision.md](agents/vision.md) (visi & pilar), [agents/tech-stack.md](agents/tech-stack.md) (keputusan API/provider gratis-dulu), [agents/architecture.md](agents/architecture.md), [agents/requirements.md](agents/requirements.md), dan [agents/scrum-guide.md](agents/scrum-guide.md).

## Menjalankan aplikasi

```sh
flutter pub get
Copy-Item .env.example .env
./scripts/flutter_with_env.ps1 run
```

Jalankan `Copy-Item` hanya saat `.env` belum ada agar konfigurasi lokal tidak tertimpa. Isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` di `.env`. Keduanya konfigurasi klien yang dapat diekstrak dari aplikasi. `.env` diabaikan Git. Jangan masukkan password pengguna, signing secret JWT, service-role key, atau Gemini API key ke Flutter.

## Pemeriksaan kualitas

Isi konfigurasi klien di `.env` lokal. Runner membuat asset `assets/config/client.env` yang hanya memuat URL dan publishable key; `.env` sumber tidak pernah dimasukkan ke APK. Signing secret JWT, service-role key, dan Gemini key hanya dipakai Supabase Edge Functions.
dart format lib test
flutter analyze
flutter test

````

GitHub Actions menjalankan pemeriksaan format, analisis statis, dan widget tests pada push ke `main` serta pull request.

## Autentikasi custom Senapath

Layar **Akun & keamanan** memakai endpoint custom `app-auth`, bukan Supabase Auth. Hanya pendaftaran/login email-password yang tersedia. Password diverifikasi server-side dan disimpan hanya sebagai PBKDF2-HMAC-SHA256 hash dengan salt acak, bukan plaintext atau ciphertext yang dapat didekripsi.

Pendaftaran langsung membuat sesi; verifikasi email dan layanan email eksternal tidak diperlukan untuk daftar atau login. Alamat email tidak diverifikasi kepemilikannya. Fitur pemulihan/lupa password tidak tersedia; simpan password dengan aman karena akun yang passwordnya terlupa tidak dapat dipulihkan.

1. Pastikan project Supabase mengizinkan custom HS256 JWT dengan secret yang sama dengan `APP_AUTH_JWT_SECRET`. Token menggunakan `role=authenticated`, `aud=authenticated`, dan `sub=<app_users.id>` agar policy `auth.uid()` berlaku. Jangan gunakan sembarang secret yang tidak dipercaya API project. Project yang hanya menerima asymmetric signing keys perlu signer yang cocok.
2. Atur secret Edge Function `APP_AUTH_JWT_SECRET`. Jangan pernah memasukkan nilai ini ke aplikasi atau Git:

   ```sh
   supabase secrets set APP_AUTH_JWT_SECRET="<signing secret yang sama dengan Supabase API>"
   ```

   `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` disediakan otomatis untuk Supabase Edge Functions. Tidak diperlukan secret atau provider email untuk autentikasi.
3. Terapkan semua migrasi (termasuk migrasi auth yang menghapus tabel verifikasi email dan pemulihan password yang tidak dipakai serta membuat pendaftaran+sesi atomik), lalu deploy function:

   ```sh
   supabase db push
   supabase functions deploy app-auth
   ```

4. Pastikan `.env` aplikasi berisi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`, lalu rebuild/restart aplikasi. Tes daftar email; jika secret backend belum lengkap, aplikasi menampilkan konfigurasi yang perlu diatur.

Jika pendaftaran gagal, periksa pesan error yang tampil terlebih dahulu. Error skema meminta migrasi dijalankan dengan `supabase db push` dan function di-deploy ulang. Untuk error lain, buka **Supabase Dashboard → Edge Functions → app-auth → Logs** dan cari reference ID yang ditampilkan aplikasi. Pastikan URL/publishable key aplikasi mengarah ke project yang sama, `APP_AUTH_JWT_SECRET` sudah disetel, dan migration history menunjukkan semua migrasi selesai.

Migrasi mempertahankan UUID akun lama dari `auth.users`, tetapi password Supabase Auth tidak dapat dipakai oleh custom auth. Akun lama yang belum memiliki password custom tidak dapat diklaim melalui daftar tanpa verifikasi kepemilikan; hubungi operator untuk migrasi aman. Ini sengaja mencegah orang lain mengambil alih data lama hanya dengan mengetik alamat email yang sama.

Di **Profil → Akun & keamanan**, pengguna dapat mendaftar/masuk dengan email dan password serta keluar dari akun cloud. Password dikirim via HTTPS ke Edge Function; token sesi disimpan di secure storage dan refresh token selalu dirotasi. Setelah pernah login, sesi tersimpan dapat dipulihkan dari layar akun memakai biometrik perangkat—password tidak disimpan, dan biometrik bukan gerbang unlock seluruh aplikasi. Login biometrik hanya tersedia jika sesi masih tersimpan; logout cloud mencabut sesi itu. Keluar dari akun cloud mempertahankan data lokal.

Nama dan tipe pesepeda di **Edit profil** disinkronkan ke profil akun Supabase saat masuk. Perubahan nama juga memperbarui nama anggota di semua tim; keanggotaan tim tetap dikelola di **Profil → Tim saya**. Saat offline, perubahan profil tetap tersimpan lokal dan aplikasi memberi tahu jika sinkronisasi cloud gagal. Foto profil dan kontak darurat tetap tersimpan terenkripsi di perangkat.

## Tema tampilan

Senapath menggunakan **tema terang** di seluruh aplikasi, terlepas dari pengaturan tampilan perangkat.

## Rute GPX dan panduan offline

1. Buka **Jelajah → Cari rute GPX** untuk mencari rute berdasarkan nama, melihat detail, atau mengelola rute GPX.
2. Pilih **Impor berkas GPX**, lalu pilih berkas dengan minimal dua titik track.
3. Kembali ke **Jelajah** dan mulai sesi. Aplikasi akan menanyakan apakah kamu ingin merekam tanpa rute atau memakai rute GPX yang tersimpan.
4. Saat sesi berlangsung, jalur pilihan dan jejak GPS tampil bersama pada peta. Untuk melihat navigasi rute lengkap, buka pratinjau rute dari perpustakaan dan pilih **Ikuti rute**.

Beranda dan tab Jelajah menampilkan basemap OpenStreetMap online. Jelajah memprioritaskan peta layar penuh; tombol melayang membuka detail atau alur mulai sesi tanpa menutupi peta dengan panel tetap. Performa sesi menampilkan perubahan kecepatan dan elevasi berdasarkan data GPS yang tersedia. Saat sesi bergerak dengan fix GPS yang memadai, peta mengikuti arah perpindahan GPS; saat diam, data GPS tidak memadai, atau sesi tidak merekam, peta kembali ke arah utara. Tombol orientasi peta dapat mengunci arah utara atau mengaktifkan kembali ikuti arah gerak. Penanda kompas tetap menunjukkan arah utara relatif terhadap orientasi perangkat memakai sensor heading yang dikoreksi magnetometer; sensor ini hanya untuk penanda, bukan untuk memutar peta. Rute tersimpan muncul di peta sesi setelah dipilih saat mulai merekam. Tombol lokasi meminta izin hanya saat digunakan; tanpa izin, peta tetap dapat digeser dan diperbesar di sekitar Yogyakarta. Tile peta dimuat online dan tidak tersedia offline; file GPX tetap tersimpan lokal dan jalurnya tetap ditampilkan saat basemap gagal dimuat atau perangkat offline. Atribusi OpenStreetMap tetap tersedia pada peta. Izin lokasi dan layanan GPS perangkat diperlukan untuk posisi langsung.

Rekaman sesi menyimpan titik GPS secara lokal. Saat mulai, aplikasi meminta izin lokasi yang diperlukan untuk sesi aktif di latar belakang; Android menampilkan notifikasi layanan foreground selama merekam dan iOS memakai background location mode. GPX terpilih tetap disimpan lokal agar progres 25/50/75/100% dan waypoint bernama pada GPX dapat memicu notifikasi lokal ketika layar terkunci. Ini bergantung pada izin OS, optimasi baterai, dan proses lokasi yang tetap berjalan; force-stop, force-quit, atau penghentian proses oleh sistem dapat menghentikan progres/notifikasi rute. Uji perilaku pada perangkat nyata sebelum mengandalkannya untuk keselamatan. Setelan **Profil → Pengaturan → Notifikasi latihan** mengontrol notifikasi progres serta pengingat mingguan yang dijadwalkan perangkat; pengingat lokal tidak memerlukan koneksi server. Ini bukan push remote FCM/APNs.

Sebelum mulai, aplikasi memeriksa ulang izin dan layanan lokasi; pada Jelajah, **Cek GPS sekarang** mencoba mendapatkan fix hingga 20 detik, sedangkan tombol lokasi di peta menunggu hingga 15 detik. Pemeriksaan awal tidak menunggu fix agar layar tidak tertahan. Jika fix belum datang, aktifkan lokasi perangkat dan coba di luar ruangan dengan pandangan langit terbuka; status akan menyebutkan apakah GPS belum dicek atau sudah dicoba tetapi belum mendapat fix. GPS aktif di pengaturan saja belum menjamin perangkat mendapat fix. Jika aplikasi dibuka kembali setelah proses dihentikan, sesi dipulihkan sebagai jeda untuk dikonfirmasi.

Pencarian rute hanya bekerja pada nama GPX yang sudah diimpor dan disimpan lokal; Jelajah tidak mencari tempat/alamat eksternal dan tidak memerlukan Google Maps API.
Jika sebelumnya pernah men-deploy Edge Function `cycling-route`, hapus function dan secret Google lama dari project Supabase yang bersangkutan (`supabase functions delete cycling-route` dan `supabase secrets unset GOOGLE_MAPS_API_KEY`). Perubahan repository ini tidak menghapus resource yang sudah di-deploy.

Beranda memakai pola feed aktivitas: ringkasan jarak/sesi tujuh hari terakhir, aktivitas terbaru, peta, dan pintasan fitur dalam kartu. **Beranda → Lihat progres** menampilkan agregat mingguan (Senin–Senin) dan bulanan dengan jarak, jumlah sesi selesai, durasi aktif, serta daftar sesi sumber yang dapat dibuka kembali. Semua sesi selesai lokal digunakan, bukan hanya 50 terbaru. Target jarak, jumlah sesi, atau durasi dapat dibuat untuk periode mingguan/bulanan; target disimpan lokal di database preferensi dan tidak disinkronkan.

Riwayat sesi menyimpan judul, jenis aktivitas (bersepeda, komuter, latihan, atau balapan), dan sumber pencatatan lokal. Judul dan jenis dapat diubah dari detail ringkasan tanpa mengubah titik GPS/telemetri. Aktivitas lama mendapat nilai bawaan saat migrasi database lokal versi 8. Metadata ini saat ini hanya lokal; payload sinkronisasi cloud tetap hanya memuat ringkasan yang dijelaskan pada bagian sinkronisasi. Dari **Profil → Riwayat sesi**, ekspor JSON dapat mencakup seluruh sesi selesai dan jejak GPS lokal. Aplikasi meminta konfirmasi sebelum ekspor karena koordinat merupakan data sensitif. Aktivitas selesai juga dapat dihapus dari perangkat; salinan yang pernah tersinkron ke cloud harus dikelola terpisah. Ekspor dan penghapusan seluruh data profil/rute/preferences maupun penghapusan akun/cloud belum tersedia.

Halaman Profil mengelompokkan kontak darurat di bagian keselamatan, riwayat/progres/rute di bagian aktivitas, dan pengaturan akun secara terpisah. **Saran dan kesan** adalah halaman statis untuk mata kuliah Pemrograman Aplikasi Mobile; teksnya masih dummy dan tidak dikirim atau disimpan.

## Tim bersepeda

Profil → **Tim saya** mendukung pembuatan tim dan keanggotaan melalui kode undangan. Pembuat tim menjadi ketua; anggota masuk dengan akun Senapath masing-masing dan menetapkan nama yang terlihat oleh tim. Ketua dapat mengangkat atau menurunkan ketua lain, dan ketua terakhir harus menyerahkan peran sebelum keluar. Dasbor hanya menampilkan sesi selesai yang dibagikan sendiri oleh pemiliknya, termasuk waktu, durasi, jarak, serta elevasi. Berbagi juga menyinkronkan ringkasan ke akun cloud. Titik GPS, jejak rute, telemetri mentah, dan lokasi live tidak dibagikan. Anggota dapat menarik ringkasan yang telah dibagikan atau keluar dari tim; keluar menghapus tautan berbagi untuk tim tersebut. Migration `20261009000000_cycling_teams.sql` menambahkan tabel, fungsi pembuatan/gabung/keluar tim, dan Row Level Security. Terapkan migrasi dengan `supabase db push`. Analisis ini hanya agregat ringkasan; deteksi insiden/anomali dan notifikasi belum termasuk.

Impor GPX menerima file hingga 10 MB, memvalidasi titik track, dan mempertahankan nama/deskripsi yang tersedia. Jarak dan elevasi mengikuti sistem satuan yang dipilih di Profil. Bagian **Profil → Penyimpanan offline** menampilkan ukuran database dan direktori cache peta serta dapat menghapus cache peta tanpa menghapus sesi atau rute.

Pemeriksaan pra-balapan menampilkan status izin notifikasi. Jika belum diberikan, pengguna dapat meminta izin OS dari layar tersebut atau membuka pengaturan perangkat bila izin pernah ditolak permanen. Ini hanya meminta izin; pengingat hidrasi dan peringatan cuaca/rute terjadwal belum tersedia.

Integrasi menggunakan layanan tile publik OpenStreetMap untuk penggunaan ringan. Jangan melakukan prefetch/download tile atau mengandalkan layanan publik ini untuk trafik produksi berskala besar; evaluasi provider tile yang sesuai dengan kebutuhan, lisensi, dan kebijakan penggunaan sebelum rilis publik.

## Konversi zona waktu dunia

Di tab **Logistik → Waktu acara**, pilih tanggal/waktu dan tekan zona waktu sumber untuk mencari kota atau zona IANA, misalnya `America/New_York`. Tambahkan satu atau lebih zona tujuan melalui **Tambah zona**. Aturan DST dan pergantian tanggal ditangani oleh database zona waktu yang dibundel; jam lokal yang tidak ada atau ambigu meminta pengguna memilih waktu/kemunculan yang valid.

## Tantangan strategi rute (belum tersedia)

Karakter rider (level/XP/gaya) tersedia di **Beranda → Karakter rider**. Sebaliknya, mini-game tantangan strategi **belum ada di aplikasi saat ini**: tidak ada route/layar game, dan migrasi database lokal versi 8 menghapus tabel hasil game lama. Bila gamifikasi reaksi/strategi tetap diinginkan, ia harus dibangun ulang sebagai item backlog (lihat [agents/scrum-guide.md](agents/scrum-guide.md) SP-37) — jangan dianggap sudah berfungsi.

## Papan peringkat rekor gowes

Peringkat tersedia melalui **Beranda → Papan peringkat** setelah masuk akun online dan menyetujui partisipasi. Nama yang diatur di profil dipakai sebagai nama publik; tidak ada alias terpisah. Durasi terlama dan jarak terjauh dicatat otomatis dari sesi selesai dan terlihat di profil. Saat partisipasi aktif, hanya dua nilai rekor tersebut yang disinkronkan ke papan peringkat—tidak perlu mengirim skor atau menyinkronkan ringkasan sesi satu per satu. Peringkat menampilkan rekor sepanjang masa; durasi dan jarak terbaik dapat berasal dari sesi berbeda. Mencabut partisipasi menarik rekor dari papan peringkat, sedangkan riwayat lokal tetap tersedia. Skor berasal dari data aplikasi dan belum diverifikasi independen. Terapkan migrasi terbaru dengan `supabase db push`.

## Sinkronisasi ringkasan sesi

Sinkronisasi memerlukan login online dan migrasi Supabase terbaru:

```sh
supabase db push
```

Setelah sesi selesai, buka ringkasannya lalu pilih **Sinkronkan ringkasan** dan setujui pengiriman. Hanya waktu mulai/selesai, durasi, jarak, jumlah sampel, informasi elevasi, dan jumlah sampel sensor yang dikirim ke `ride_session_summaries`; koordinat GPS, geometri rute, dan telemetri mentah tidak dikirim. Status lokal menjadi tersinkron hanya setelah upsert server berhasil. Kunci idempotensi gabungan `user_id, session_id` mencegah retry membuat duplikat, RLS membatasi akses per akun, dan penghapusan akun menghapus ringkasan cloud melalui foreign key cascade.

## Chat AI (Supabase + Gemini)

Chat hanya mengirim pesan setelah pengguna menyetujui. Rute lokal dan preferensi latihan hanya disertakan bila dipilih. Percakapan tidak disimpan di riwayat lokal; permintaan diteruskan melalui Supabase ke Google Gemini. Jangan masukkan kontak darurat atau informasi sensitif.

1. Buat proyek Supabase. Supabase Auth email provider tidak digunakan untuk daftar/login custom ini.
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
supabase functions deploy rider-coach
```

Untuk menjalankan Edge Function secara lokal, isi `GEMINI_API_KEY` di `.env` lalu gunakan `supabase functions serve --env-file .env`; Supabase CLI menyediakan variabel Supabase lokal bagi function. Saat deploy, masukkan Gemini key ke Supabase Secrets seperti perintah di atas. Jangan simpan `SUPABASE_SERVICE_ROLE_KEY` di Flutter atau commit ke repo.

Jika chat tidak mendapat jawaban, pastikan akun online sudah masuk, migrasi kuota sudah diterapkan, lalu cek nama secrets tanpa menampilkan nilainya dan lihat log function:

```sh
supabase secrets list
supabase functions logs rider-assistant --project-ref your-project-ref
supabase functions logs rider-coach --project-ref your-project-ref
```

Untuk memastikan key benar-benar dapat melihat model yang mendukung `generateContent`, jalankan pemeriksaan ini di PowerShell pada mesin tepercaya setelah `GEMINI_API_KEY` tersedia sebagai environment variable. Respons hanya menampilkan nama model; key tidak dicetak:

```powershell
if (-not $env:GEMINI_API_KEY) { throw 'Set GEMINI_API_KEY di environment terlebih dahulu.' }
$models = Invoke-RestMethod `
  -Uri 'https://generativelanguage.googleapis.com/v1beta/models' `
  -Headers @{ 'x-goog-api-key' = $env:GEMINI_API_KEY }
$models.models |
  Where-Object { $_.supportedGenerationMethods -contains 'generateContent' } |
  Select-Object name, displayName
```

Atur `GEMINI_MODEL` ke nama yang tercantum, tanpa awalan `models/` (misalnya `gemini-2.5-flash` bila model itu terlihat). Jika daftar model berhasil tetapi panggilan menghasilkan 400/404, model salah/tidak tersedia untuk key atau format namanya keliru; 401/403 menunjukkan key/API/project access ditolak; 429 berarti kuota atau rate limit. Pastikan Gemini API aktif pada project Google yang menerbitkan key, dan cek kuota/billing serta log Edge Function. `supabase secrets list` hanya untuk memeriksa nama secret, bukan nilainya.

Error sesi berarti login ulang diperlukan; error konfigurasi berarti periksa `GEMINI_API_KEY`, `GEMINI_MODEL`, dan function yang ter-deploy; error kuota harian tidak akan hilang dengan mengirim ulang pesan.

Kartu **Pelatih AI saat gowes** di Beranda merupakan rekomendasi kontekstual yang terpisah dari chat: pengguna memintanya saat sesi aktif dengan GPX, lalu memberi persetujuan sebelum ringkasan nama rute, progres, durasi, kecepatan, jarak tersisa, dan checkpoint berikutnya dikirim ke `rider-coach`. Koordinat GPS mentah tidak dikirim. Rekomendasi dapat dikirim sebagai notifikasi setelah pengguna menekan tombolnya. Edge Function memakai secret Gemini yang sama dan kuota 30 permintaan per akun per hari.

## Level rider dan bukti aktivitas

Beranda menampilkan level, XP, dan gaya rider; gaya Sprinter, Climber, Explorer, atau Ace/All-rounder diatur di **Profil → Pengaturan → Preferensi**, lalu disinkronkan ke profil cloud ketika akun online tersedia dan tampil pada kartu anggota tim serta leaderboard. XP masih dihitung dari sesi lokal dan angka profil cloud berasal dari aplikasi, bukan verifikasi independen.

Detail **Bukti perjalanan** menyimpan hash berantai lokal untuk ringkasan sesi selesai tanpa koordinat GPS dan menyediakan pemeriksaan integritas. Dengan persetujuan pengguna, **Sinkronkan bukti** mengirim metadata minimum (indeks, waktu, jarak, durasi, dan hash) ke ledger append-only di database cloud Supabase; GPS, nama, dan email tidak dikirim. Tidak ada integrasi Ethereum, wallet, RPC, maupun biaya transaksi. Ini merupakan ledger hash tersinkron di cloud, bukan blockchain terdesentralisasi: operator database tetap mengelola penyimpanan, dan data perjalanan awal tetap berasal dari aplikasi pengguna, bukan diverifikasi independen.

### Seed data tim demo

`supabase/seed.sql` menyediakan dua tim demo (masing-masing empat rider: Sprinter, Climber, Explorer, dan Ace), level/XP contoh, serta rekor leaderboard. Setelah menjalankan migrasi, jalankan seed secara eksplisit melalui Supabase Dashboard → SQL Editor atau `supabase db reset` untuk database lokal yang memang boleh di-reset. Seed tidak dijalankan oleh `supabase db push`. Akun demo memakai alamat `example.invalid` dan password kosong sehingga merupakan data roster/leaderboard saja, tidak bisa login; jangan gunakan seed ini sebagai identitas pengguna produksi. Akun aplikasi yang sudah terdaftar bisa masuk ke tim demo dengan kode `A1000000000040008000000000000001` atau `A2000000000040008000000000000002`.

4. Jalankan aplikasi dengan URL proyek dan publishable key Supabase dari `.env`:

```sh
.\scripts\flutter_with_env.ps1 build apk --release
```

Publishable key memang digunakan oleh aplikasi klien; jangan pernah memasukkan signing secret JWT, service-role key, atau Gemini API key ke runner Flutter. Password dikelola server-side oleh custom auth dan tidak disimpan oleh aplikasi. Function AI membatasi setiap akun aplikasi hingga 30 permintaan per hari. Halaman **Profil → Saran dan kesan** saat ini hanya menampilkan teks statis untuk mata kuliah dan tidak mengirim atau menyimpan masukan. Atur kuota dan batas biaya Gemini di Google AI Studio/Google Cloud. Chat memerlukan sesi akun.
