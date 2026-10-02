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

## Rute GPX dan panduan offline

1. Buka tab **Rute**, lalu pilih tombol **Impor GPX**.
2. Pilih berkas GPX yang berisi minimal dua titik track.
3. Ketuk rute yang tersimpan untuk melihat bentuk jalur, jarak, dan elevasi yang tersedia.
4. Pilih **Ikuti rute** untuk melihat jalur bersama posisi GPS, progres, jarak tersisa, dan peringatan bila fix GPS akurat menunjukkan kamu keluar jalur.

Preview rute dan panduan menampilkan basemap OpenStreetMap saat internet tersedia, dengan geometri GPX dan posisi GPS di atasnya. Tile peta dimuat online dan tidak tersedia offline; file GPX tetap tersimpan lokal dan jalurnya tetap ditampilkan saat basemap gagal dimuat atau perangkat offline. Atribusi OpenStreetMap ditampilkan pada peta. Pencarian tempat/rute, petunjuk belokan, dan reroute belum tersedia karena memerlukan provider/service terpisah. Izin lokasi dan layanan GPS perangkat tetap diperlukan untuk posisi langsung.

Integrasi menggunakan layanan tile publik OpenStreetMap untuk penggunaan ringan. Jangan melakukan prefetch/download tile atau mengandalkan layanan publik ini untuk trafik produksi berskala besar; evaluasi provider tile yang sesuai dengan kebutuhan, lisensi, dan kebijakan penggunaan sebelum rilis publik.

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
