# Tech Stack & Keputusan API Senapath — Gratis Dulu

> Dokumen ini adalah **register keputusan provider/API**. Ia menjawab pertanyaan "API apa yang dipakai?" untuk visi [vision.md](vision.md) dan melengkapi [architecture.md](architecture.md). Prioritas: **gratis / open-source**, dapat di-self-host, tanpa lock-in, dan punya fallback.

## 0. Prinsip Pemilihan Provider

1. **Gratis/OSS lebih dulu.** Pilih provider tanpa API key atau dengan free tier yang cukup untuk proyek/tugas akhir.
2. **Adapter, bukan ketergantungan langsung.** Setiap provider diisolasi di lapisan Data/Integration; domain tidak boleh mengimpor SDK vendor (lihat [architecture.md](architecture.md) §2).
3. **Selalu ada fallback.** Setiap integrasi punya jalur degradasi (cache lokal, provider alternatif, atau "belum tersedia" yang jujur).
4. **Rahasia di server.** API key provider tidak pernah masuk bundle Flutter; panggilan ber-secret lewat Edge Functions.
5. **Verifikasi kuota.** Semua angka free tier adalah indikatif per penulisan dokumen; **wajib diverifikasi** ulang di dashboard provider sebelum diandalkan produksi (dicatat di kolom Status).

## 1. Ringkasan Tumpukan yang Diputuskan

| Lapisan | Keputusan | Biaya |
| --- | --- | --- |
| Runtime aplikasi | Flutter / Dart | Gratis |
| UI & state | `flutter_bloc`, `go_router`, `get_it` | Gratis/OSS |
| Database lokal | **Drift di atas SQLite** | Gratis/OSS |
| Backend & DB cloud | **Supabase** (Postgres, Edge Functions, Storage, Realtime) | Free tier |
| Auth | **Custom email/password** via Edge Function (bukan Supabase Auth) | Gratis |
| Basemap | **OpenFreeMap** (vektor) → fallback tile raster OSM | Gratis |
| Render peta | `flutter_map` (raster) → **MapLibre GL** (vektor) | OSS |
| Geocoding / search | **Photon** (OSS) → fallback **Nominatim** | Gratis/OSS |
| Routing & turn-by-turn | **BRouter** (offline) / **Valhalla** (self-host) → fallback **OpenRouteService** | Gratis/OSS |
| Elevasi | **Open-Meteo Elevation** / SRTM | Gratis |
| Cuaca & angin | **Open-Meteo** | Gratis (non-komersial) |
| POI | **OSM Overpass API** | Gratis |
| AI/LLM | **Gemini free tier** → fallback Groq / OpenRouter; **Ollama** lokal | Free tier |
| Push remote | **FCM** + **APNs** via Edge Function | Gratis |
| Media/foto | **Supabase Storage** → opsi **Cloudflare R2** | Free tier |
| Kurs mata uang | **Frankfurter** (ECB) | Gratis, tanpa key |
| Kesehatan/wearable | **Health Connect** + **HealthKit** + impor FIT/GPX/TCX | Gratis |
| Blockchain | **Ledger hash** + anchor head hash ke EVM testnet (Ethereum Sepolia) via JSON-RPC & relayer Edge Function | Gas testnet gratis |
| CI | **GitHub Actions** | Free tier |

## 2. Register Keputusan Provider

### 2.1 Backend, Data, dan Auth

| Area | Pilihan utama | Mengapa | Free tier / batas (indikatif) | Fallback | Status |
| --- | --- | --- | --- | --- | --- |
| Database cloud | **Supabase Postgres** | Sudah dipakai; Postgres + RLS + SQL; dapat self-host | Free: DB & storage terbatas, project pause saat idle lama | Self-host Supabase / Postgres di VPS | Dipakai; migrasi belum diverifikasi live |
| API/service | **Supabase Edge Functions (Deno)** | Menyembunyikan secret, cocok untuk provider ber-key | Free: jumlah invocations/bulan terbatas | VPS + fungsi serverless OSS | Dipakai |
| Auth | **Custom email/password** (`app-auth`) | Sesuai kebutuhan sponsor; hash PBKDF2 server-side; JWT HS256 | Gratis | Supabase Auth (bila kebijakan berubah) | Dipakai |
| Realtime (feed/live) | **Supabase Realtime** | Untuk feed/komen/live tracking opsional | Free: koneksi & pesan terbatas | Polling berkala | Belum dipakai; rencana |
| Storage media | **Supabase Storage** (bucket private + signed URL) | Terintegrasi RLS; gratis | Free: ruang & egress terbatas | **Cloudflare R2** (storage + egress lebih longgar) | Sebagian (avatar lokal terenkripsi) |

### 2.2 Peta, Geocoding, Routing, Cuaca

| Area | Pilihan utama | Mengapa | Free tier / batas (indikatif) | Fallback | Status |
| --- | --- | --- | --- | --- | --- |
| Basemap | **OpenFreeMap** (vektor, tanpa key) | Gratis, tanpa batas keras, self-hostable | Tanpa key; fair use | Tile raster **OSM** yang sudah dipakai | Raster OSM dipakai; vektor direncanakan |
| Render peta | `flutter_map` → **MapLibre GL** | Raster sekarang; vektor/rotasi untuk skala produksi | OSS | — | `flutter_map` dipakai |
| Geocoding/autocomplete | **Photon** (Komoot, OSS) | Cepat untuk autocomplete, self-hostable | Public instance fair use | **Nominatim** (max ~1 req/detik, wajib User-Agent) | Belum; rencana |
| Routing (rencana rute) | **BRouter** (offline) & **Valhalla** (server) | Profil khusus sepeda/gravel; BRouter bisa offline | OSS; self-host | **OpenRouteService** free (≈2k req/hari) / **GraphHopper** free (≈500/hari) | Belum; rencana |
| Turn-by-turn | Dari rute yang dihitung BRouter/Valhalla | GPX mentah tidak punya instruksi belokan yang tepercaya | OSS | Tampilkan arahan "off-route" + jalur saja | Belum |
| Elevasi | **Open-Meteo Elevation / SRTM** | Gratis, tanpa key, cukup untuk profil elevasi | Fair use | Hitung dari GPS altitude (berlabel estimasi) | Elevasi GPS parsial sudah ada |
| Cuaca & angin | **Open-Meteo** | Gratis non-komersial, tanpa key, termasuk angin (penting untuk cyclist) | Fair use | Sembunyikan bila gagal | Belum; rencana (FR-09/SP-18) |
| POI (warung, air, puncak) | **OSM Overpass API** | Data OSM gratis | Fair use; rate terbatas | Sembunyikan POI bila gagal | Belum |

### 2.3 AI / LLM

| Area | Pilihan utama | Mengapa | Free tier / batas (indikatif) | Fallback | Status |
| --- | --- | --- | --- | --- | --- |
| LLM generatif | **Google Gemini free tier** (`gemini-2.5-flash` / `flash-lite`) | Sudah terintegrasi via Edge Function; kualitas baik | Free tier rate-limited + kuota harian per akun (30/hari saat ini) | **Groq** free tier (Llama) / **OpenRouter** model gratis | Dipakai (`rider-assistant`, `rider-coach`) |
| Dev/offline | **Ollama** lokal | Menghindari biaya & kuota saat pengembangan | Gratis lokal | — | Belum; rekomendasi dev |
| AI analitik non-generatif | Komputasi lokal / Postgres | Dapat ditelusuri, tanpa biaya provider | Gratis | — | Sebagian (progres lokal) |
| Pengenalan gambar | Ditunda | Tidak masuk visi v1 | — | — | Belum |

**Aturan:** secret `GEMINI_API_KEY` hanya di Supabase Secrets; client memanggil Edge Function, bukan provider langsung. Fallback provider LLM dipilih server-side agar tidak membocorkan key.

### 2.4 Sosial, Segmen, Notifikasi, Kesehatan

| Area | Pilihan utama | Mengapa | Free tier / batas (indikatif) | Fallback | Status |
| --- | --- | --- | --- | --- | --- |
| Feed & kudos & komentar | **Supabase Postgres + RLS** | Sudah ada pola; tanpa vendor sosial tambahan | Sesuai kuota DB | — | Belum (feed Beranda = aktivitas lokal) |
| Follow | Postgres tabel `follows` + RLS | Sederhana, murah | Kuota DB | — | Belum |
| Klub/Tim | **RFC `cycling_teams`** (sudah ada) | Diperluas jadi klub dengan feed | Kuota DB | — | Sebagian |
| Segmen | Buat di Postgres; matching **on-device**, leaderboard **RPC SECURITY DEFINER** | Menghindari biaya layanan pihak ketiga | Kuota DB + komputasi server terbatas | — | Belum |
| Push remote | **FCM** (Android) + **APNs** (iOS) via Edge Function | Gratis, standar platform | Gratis | **OneSignal** free tier | Belum (hanya lokal) |
| Notifikasi lokal | `flutter_local_notifications` | Jalan offline | Gratis | — | Dipakai |
| Import kesehatan | **Health Connect** (Android) + **HealthKit** (iOS) | Gratis, on-device, ramah privasi | Gratis | Impor file FIT/GPX/TCX | Belum |
| Wearable Garmin | Garmin Health API | Resmi, kaya metrik | Bergantung approval partner | Health Connect/HealthKit + file | Blocked (approval) |
| Impor file | FIT/GPX/TCX (parser lokal) | Gratis, tanpa akun pihak ketiga | Gratis | — | GPX/JSON dipakai |

### 2.5 Utilitas & Kejujuran Ledger

| Area | Pilihan utama | Mengapa | Free tier / batas (indikatif) | Fallback | Status |
| --- | --- | --- | --- | --- | --- |
| Kurs mata uang | **Frankfurter** (ECB) | Gratis, tanpa key, cukup akurat harian | Fair use | Input manual (sudah ada) | Manual dipakai; otomatis rencana |
| Blockchain publik | Ditunda; gunakan **ledger hash** tersinkron | Jujur soal biaya & privasi; chain publik belum perlu | — | Ethereum Sepolia (staging) bila PO memutuskan wajib | Ledger hash dipakai |
| Analitik crash | **Sentry** free tier (opsional) | Redaksi data sensitif | Free: event terbatas | Log lokal / tanpa pihak ketiga | Belum |
| CI/CD | **GitHub Actions** | Sudah dipakai | Free: menit/bulan terbatas | Build lokal | Dipakai |

## 3. Peta Sumber Data (Data Provenance) vs Provider

Ringkasan singkat bagaimana provider mengisi model data kanonis ([scrum-guide.md](scrum-guide.md) §11):

- `LocationSample` ← GPS perangkat (utama); elevasi dari Open-Meteo/SRTM atau GPS (label estimasi).
- `SensorSample` ← `sensors_plus` / Health Connect / HealthKit / BLE (Fase lanjut).
- `Route` ← impor GPX + routing BRouter/Valhalla + POI Overpass.
- `ActivitySummary` ← komputasi lokal; dikonfirmasi server saat sinkron.
- `ExternalConnection` ← token provider (aman, server-side untuk yang ber-secret).

## 4. Rencana Adopsi Bertahap (Gratis → Produksi)

1. **Sekarang:** Supabase (DB/Edge/Storage), raster OSM, Gemini free tier, kurs manual, custom auth, ledger hash.
2. **Pilar 2 (rencana rute):** tambah Photon + BRouter/Valhalla + Open-Meteo Elevation.
3. **Pilar 4 (sosial):** feed/follow/kudos/komentar di Postgres, segmen v1, FCM/APNs.
4. **Skala & biaya:** evaluasi OpenFreeMap vektor + MapLibre, Cloudflare R2, Groq/OpenRouter sebagai fallback LLM, Ollama untuk dev.
5. **Kesehatan:** Health Connect/HealthKit, impor FIT/TCX; Garmin hanya setelah approval.

## 5. Tabel Risiko Provider

| Risiko | Dampak | Mitigasi |
| --- | --- | --- |
| Free tier berubah / dihentikan | Layanan cloud mati | Adapter + fallback; self-host; dokumentasi migrasi |
| Rate limit geocoding/routing publik | Autocomplete/routing gagal | Cache hasil, debounce, self-host Photon/Valhalla, fallback "belum tersedia" jujur |
| Kuota Gemini habis | Chat/rekomendasi gagal | Fallback Groq/OpenRouter server-side; kuota per akun; pesan jujur |
| Supabase pause saat idle | Sinkronisasi gagal | Retry/outbox lokal; pesan status; upgrade saat produksi |
| Biaya egress media | Tagihan tak terduga | Kompresi gambar, signed URL, R2 bila perlu, batas ukuran |
| Lock-in provider | Migrasi mahal | Isolasi di lapisan Data; model domain tidak impor SDK vendor |

---

*Setiap provider baru yang ditambahkan ke implementasi harus diperbarui di register ini dengan kolom status, batas free tier, fallback, dan pemilik keputusan. Angka free tier yang tercantum adalah indikatif dan harus diverifikasi sebelum dijanjikan ke pengguna.*
