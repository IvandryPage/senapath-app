# Senapath

Aplikasi pendamping latihan dan balapan sepeda.

## Menjalankan aplikasi

```sh
flutter pub get
flutter run
```

## Pemeriksaan kualitas

```sh
dart format lib test
flutter analyze
flutter test
```

GitHub Actions menjalankan pemeriksaan format, analisis statis, dan widget tests pada push ke `main` serta pull request.

## Rute GPX dan panduan offline

1. Buka tab **Rute**, lalu pilih tombol **Impor GPX**.
2. Pilih berkas GPX yang berisi minimal dua titik track.
3. Ketuk rute yang tersimpan untuk melihat bentuk jalur, jarak, dan elevasi yang tersedia.
4. Pilih **Ikuti rute** untuk melihat jalur bersama posisi GPS, progres, jarak tersisa, dan peringatan bila fix GPS akurat menunjukkan kamu keluar jalur.

Panduan GPX dapat digunakan tanpa internet setelah file tersimpan. Preview belum menampilkan basemap jalan, petunjuk belokan, atau reroute; fitur online tersebut menunggu provider peta/routing yang disetujui. Izin lokasi dan layanan GPS perangkat tetap diperlukan untuk posisi langsung.

## Chat AI (Supabase + Gemini)

Chat hanya mengirim pesan setelah pengguna menyetujui. Rute lokal dan preferensi latihan hanya disertakan bila dipilih. Percakapan tidak disimpan di riwayat lokal; permintaan diteruskan melalui Supabase ke Google Gemini. Jangan masukkan kontak darurat atau informasi sensitif.

1. Buat proyek Supabase, pasang Supabase CLI, lalu aktifkan **Anonymous Sign-Ins** pada Authentication.
2. Login dan tautkan proyek lokal sebelum menerapkan migrasi:

```sh
supabase login
supabase link --project-ref your-project-ref
```

3. Terapkan migrasi kuota harian, atur secret Gemini hanya di Supabase, lalu deploy function:

```sh
supabase db push
supabase secrets set GEMINI_API_KEY=your-gemini-api-key
supabase functions deploy rider-assistant
supabase functions deploy submit-feedback
```

4. Jalankan aplikasi dengan URL proyek dan publishable key Supabase:

```sh
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key
```

Publishable key memang digunakan oleh aplikasi klien; jangan pernah memasukkan service-role key atau Gemini API key ke `--dart-define`. Function membatasi tiap akun anonim hingga 30 permintaan per hari; tabel kuota hanya menyimpan ID anonim, tanggal, dan jumlah permintaan, bukan isi chat. Feedback terkirim disimpan di tabel `user_feedback` untuk ditinjau tim; hapus data secara berkala melalui dashboard/database sesuai kebijakan retensi proyek. Atur juga kuota dan batas biaya Gemini di Google AI Studio/Google Cloud. Chat dan pengiriman feedback belum aktif sampai function berhasil dideploy dan konfigurasi Supabase diberikan.
