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
3. Terapkan migrasi dan deploy function:

   ```sh
   supabase db push
   supabase functions deploy app-auth
   ```

4. Pastikan `.env` aplikasi berisi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`, lalu rebuild/restart aplikasi. Tes daftar email; jika secret backend belum lengkap, aplikasi sekarang menampilkan secret/konfigurasi yang perlu diatur.

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

Beranda dan tab Jelajah menampilkan basemap OpenStreetMap online, dengan jalur GPX dan posisi GPS di atasnya jika tersedia. Tombol lokasi meminta izin hanya saat digunakan; tanpa izin, peta tetap dapat digeser dan diperbesar di pusat awal Jakarta. Tile peta dimuat online dan tidak tersedia offline; file GPX tetap tersimpan lokal dan jalurnya tetap ditampilkan saat basemap gagal dimuat atau perangkat offline. Peta menyediakan status tile dan tombol muat ulang, serta atribusi OpenStreetMap. Pencarian tempat/rute, petunjuk belokan, dan reroute belum tersedia karena memerlukan provider/service terpisah. Izin lokasi dan layanan GPS perangkat diperlukan untuk posisi langsung.

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
