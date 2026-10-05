# Senapath

Aplikasi pendamping latihan dan balapan sepeda.

## Menjalankan aplikasi

```sh
flutter pub get
Copy-Item .env.example .env
./scripts/flutter_with_env.ps1 run
```

Jalankan `Copy-Item` hanya saat `.env` belum ada agar konfigurasi lokal tidak tertimpa. Isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` di `.env`. Keduanya adalah konfigurasi klien yang dapat diekstrak dari aplikasi; keamanan data wajib ditegakkan dengan Supabase Auth dan RLS. `.env` diabaikan Git. Jangan masukkan password pengguna, service-role key, atau Gemini API key ke Flutter.

## Pemeriksaan kualitas

Isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` di `.env` lokal. Runner membuat asset `assets/config/client.env` yang hanya memuat dua nilai publik tersebut; `.env` sumber tidak pernah dimasukkan ke APK. Gemini key hanya dipakai Supabase Edge Functions. Jangan masukkan password pengguna atau service-role key ke Flutter/app.
dart format lib test
flutter analyze
flutter test

````

GitHub Actions menjalankan pemeriksaan format, analisis statis, dan widget tests pada push ke `main` serta pull request.

## Login Google (Supabase Auth)

Layar **Akun online** mendukung login Google melalui OAuth Supabase. Agar login dapat bekerja:

1. Di Supabase Dashboard, buka **Authentication → Providers → Google**, aktifkan provider, lalu isi OAuth Client ID dan Client Secret yang dibuat di Google Cloud. Pada Google Cloud, tambahkan callback URL yang ditampilkan Supabase sebagai authorized redirect URI. Credential provider disimpan di Supabase, bukan di aplikasi.
2. Di Supabase Dashboard, buka **Authentication → URL Configuration** dan tambahkan `senapath://login-callback/` ke daftar **Redirect URLs** yang diizinkan.
3. Pastikan `.env` lokal berisi URL proyek dan publishable key Supabase, lalu jalankan aplikasi ulang. Tombol **Lanjutkan dengan Google** membuka alur OAuth; session hanya dianggap aktif setelah callback kembali ke aplikasi dan Supabase mengonfirmasi perubahan auth.

Callback scheme native `senapath` sudah didaftarkan pada Android dan iOS. Setup Google Cloud/Supabase serta alur OAuth live tetap perlu diuji menggunakan project dan perangkat target. Login Google ini tidak mengaktifkan biometric unlock; biometrik tetap merupakan kunci lokal terpisah.

Di **Profil → Akun online**, pengguna dapat mendaftar/masuk dengan email dan password, memulai login Google, meminta reset password, serta keluar dari akun cloud. Password hanya dikirim ke Supabase Auth melalui HTTPS dan tidak disimpan oleh aplikasi. Reset password selalu menampilkan konfirmasi generik agar keberadaan suatu email tidak diungkapkan. Keluar dari akun cloud mempertahankan data lokal; permintaan AI yang sedang berjalan dibuang dari tampilan dan pembaruan UI sync yang tertunda diabaikan saat identitas akun berubah. Permintaan jaringan yang sudah terkirim tidak dapat ditarik kembali.

## Tema tampilan

Pilih **Sistem**, **Terang**, atau **Gelap** di bagian **Profil → Tema tampilan**. Pilihan disimpan di preferensi lokal Drift dan diterapkan ke seluruh aplikasi. Mode Sistem mengikuti pengaturan tampilan perangkat.

## Rute GPX dan panduan offline

1. Buka tab **Rute**, lalu pilih tombol **Impor GPX**.
2. Pilih berkas GPX yang berisi minimal dua titik track.
3. Ketuk rute yang tersimpan untuk melihat bentuk jalur, jarak, dan elevasi yang tersedia.
4. Pilih **Ikuti rute** untuk melihat jalur bersama posisi GPS, progres, jarak tersisa, dan peringatan bila fix GPS akurat menunjukkan kamu keluar jalur.

Preview rute dan panduan menampilkan basemap OpenStreetMap saat internet tersedia, dengan geometri GPX dan posisi GPS di atasnya. Tile peta dimuat online dan tidak tersedia offline; file GPX tetap tersimpan lokal dan jalurnya tetap ditampilkan saat basemap gagal dimuat atau perangkat offline. Atribusi OpenStreetMap ditampilkan pada peta. Pencarian tempat/rute, petunjuk belokan, dan reroute belum tersedia karena memerlukan provider/service terpisah. Izin lokasi dan layanan GPS perangkat tetap diperlukan untuk posisi langsung.

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
````

3. Terapkan migrasi kuota harian, atur secret Gemini hanya di Supabase, lalu deploy function:

```sh
supabase db push
supabase secrets set GEMINI_API_KEY=your-gemini-api-key
supabase functions deploy rider-assistant
supabase functions deploy submit-feedback
```

Untuk menjalankan Edge Function secara lokal, isi `GEMINI_API_KEY` di `.env` lalu gunakan `supabase functions serve --env-file .env`; Supabase CLI menyediakan variabel Supabase lokal bagi function. Saat deploy, masukkan Gemini key ke Supabase Secrets seperti perintah di atas. Jangan simpan `SUPABASE_SERVICE_ROLE_KEY` di Flutter atau commit ke repo.

4. Jalankan aplikasi dengan URL proyek dan publishable key Supabase dari `.env`:

```sh
.\scripts\flutter_with_env.ps1 build apk --release
```

Publishable key memang digunakan oleh aplikasi klien dan diteruskan sebagai compile-time define; jangan pernah memasukkan service-role key atau Gemini API key ke runner Flutter. Email/password dikelola Supabase Auth; aplikasi tidak menyimpan password. Function AI membatasi setiap akun Supabase hingga 30 permintaan per hari. Feedback terkirim disimpan di tabel `user_feedback` untuk ditinjau tim; hapus data secara berkala sesuai kebijakan retensi proyek. Atur kuota dan batas biaya Gemini di Google AI Studio/Google Cloud. Chat dan feedback memerlukan sesi akun online. Email confirmation/reset juga memerlukan provider Email, template, SMTP, serta redirect URL yang sesuai.
