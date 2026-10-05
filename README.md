# Senapath

Aplikasi pendamping latihan dan balapan sepeda.

## Menjalankan aplikasi

```sh
flutter pub get
Copy-Item .env.example .env
./scripts/flutter_with_env.ps1 run
```

Jalankan `Copy-Item` hanya saat `.env` belum ada agar konfigurasi lokal tidak tertimpa. Isi `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_SERVER_CLIENT_ID`, dan `GOOGLE_IOS_CLIENT_ID` di `.env`. ID Google dan konfigurasi Supabase adalah konfigurasi klien yang dapat diekstrak dari aplikasi. `.env` diabaikan Git. Jangan masukkan password pengguna, signing secret JWT, service-role key, atau Gemini API key ke Flutter.

## Pemeriksaan kualitas

Isi konfigurasi klien di `.env` lokal. Runner membuat asset `assets/config/client.env` yang hanya memuat URL, publishable key, dan OAuth client IDs publik; `.env` sumber tidak pernah dimasukkan ke APK. Signing secret JWT, Resend key, service-role key, dan Gemini key hanya dipakai Supabase Edge Functions.
dart format lib test
flutter analyze
flutter test

````

GitHub Actions menjalankan pemeriksaan format, analisis statis, dan widget tests pada push ke `main` serta pull request.

## Autentikasi custom Senapath

Layar **Akun online** memakai endpoint `app-auth`, bukan Supabase Auth. Email/password diverifikasi server-side; password disimpan hanya sebagai PBKDF2-HMAC-SHA256 hash dengan salt acak, bukan plaintext atau ciphertext yang dapat didekripsi. Google Sign-In memperoleh ID token di perangkat dan Edge Function memverifikasinya dengan Google JWKS serta audience server client ID.

1. Buat OAuth client IDs Android, iOS, dan Web di Google Cloud. Masukkan Web client ID sebagai `GOOGLE_SERVER_CLIENT_ID`; isi Android/iOS package/bundle identifiers dan SHA fingerprints sesuai project. `GOOGLE_IOS_CLIENT_ID` dipakai untuk inisialisasi native iOS; tambahkan reversed iOS client ID ke URL schemes di `ios/Runner/Info.plist`.
2. Set Edge Function secrets `APP_AUTH_JWT_SECRET` dan `GOOGLE_SERVER_CLIENT_ID`. `APP_AUTH_JWT_SECRET` harus sama dengan signing secret JWT yang dipercaya Supabase Data API; secret minimal 32 karakter ini tidak boleh dimasukkan ke aplikasi. JWT memuat `role=authenticated`, `aud=authenticated`, dan `sub=<app_users.id>` sehingga policy yang memakai `auth.uid()` tetap berlaku. Jika project hanya menerima asymmetric signing keys, konfigurasi custom signer harus disesuaikan sebelum deploy.
3. Untuk verifikasi email dan pemulihan akun set `RESEND_API_KEY`, `AUTH_EMAIL_FROM`, `AUTH_EMAIL_VERIFICATION_URL=senapath://login-callback/verify-email`, dan `AUTH_PASSWORD_RESET_URL=senapath://login-callback/reset-password`; daftarkan domain pengirim di Resend. Token verifikasi berlaku 24 jam dan token reset sekali-pakai berlaku 20 menit.
4. Jalankan `supabase db push`, lalu deploy `app-auth`, `rider-assistant`, dan `submit-feedback`. Pastikan seluruh fungsi memiliki secret yang diperlukan dan project Supabase memang mempercayai signing key yang dipakai.
5. Isi client IDs publik di `.env`, jalankan ulang aplikasi, dan uji email, Google, refresh, reset, logout, serta RLS dengan project nyata.

Migrasi mempertahankan UUID akun `auth.users` lama saat menyalin identitas ke `app_users`, tetapi password Supabase lama tidak dapat dipakai oleh autentikasi custom. Pengguna lama dapat menautkan akun melalui Google dengan email terverifikasi yang sama; bila tidak, operator perlu membantu migrasi akun atau pengguna harus mendaftar dengan alamat email lain. Migrasi tidak menyalin password dari Supabase Auth. Login Google tidak mengaktifkan biometric unlock; biometrik tetap merupakan kunci lokal terpisah.

Di **Profil → Akun online**, pengguna dapat mendaftar/masuk dengan email dan password, masuk dengan Google, meminta reset password, serta keluar dari akun cloud. Password dikirim via HTTPS ke Edge Function; token sesi disimpan di secure storage dan refresh token selalu dirotasi. Reset password menampilkan konfirmasi generik agar keberadaan suatu email tidak diungkapkan. Keluar dari akun cloud mempertahankan data lokal.

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

1. Buat proyek Supabase dan aktifkan provider **Email** di Authentication. Pilih kebijakan verifikasi email; untuk produksi, atur SMTP tepercaya dan redirect URL verifikasi/reset yang diizinkan.
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

Publishable key memang digunakan oleh aplikasi klien; jangan pernah memasukkan signing secret JWT, service-role key, Resend key, atau Gemini API key ke runner Flutter. Password dikelola server-side oleh custom auth dan tidak disimpan oleh aplikasi. Function AI membatasi setiap akun aplikasi hingga 30 permintaan per hari. Feedback terkirim disimpan di tabel `user_feedback` untuk ditinjau tim; hapus data secara berkala sesuai kebijakan retensi proyek. Atur kuota dan batas biaya Gemini di Google AI Studio/Google Cloud. Chat dan feedback memerlukan sesi akun online. Verifikasi/reset email memerlukan provider email dan secrets Edge Function sesuai bagian autentikasi.
