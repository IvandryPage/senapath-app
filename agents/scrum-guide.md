# Scrum Guide dan Product Backlog v2 Senapath

## 1. Tujuan dan Product Goal

**Product Goal:** pembalap dapat menyiapkan rute yang terlihat, merekam sesi dengan andal, tetap memakai data penting secara offline, dan memahami dengan tepat fitur online mana yang aktif. Produk hanya disebut siap produksi setelah layanan, keamanan, perangkat sasaran, dan pemulihan benar-benar diuji.

Product Backlog v2 ini menggantikan asumsi lama bahwa penyelesaian 12 sprint otomatis berarti produk siap. Urutan berikut berbasis risiko dan keluhan penggunaan, bukan kalender atau velocity yang belum diukur. PO dapat mengubah urutan setelah bukti Sprint Review.

## 2. Baseline yang Terverifikasi

Ada implementasi lokal untuk unlock perangkat, sesi Drift, impor/ekspor GPX/JSON, latihan reaksi, konversi logistik, chat AI, feedback, dan penyimpanan offline. GPX kini menyimpan geometri terenkripsi; rute dapat dipreview dan diikuti dengan posisi GPS, progres, jarak tersisa, dan peringatan keluar jalur. Ini panduan track offline, bukan basemap jalan atau instruksi belok.

Berikut ini **belum boleh diklaim berfungsi produksi**:

- Basemap, pencarian rute online, geocoding, elevasi, dan POI provider belum dipilih atau dikonfigurasi. Preview GPX adalah bentuk jalur, bukan peta jalan atau navigasi.
- Basemap, pencarian rute online, geocoding, elevasi, dan POI provider belum dipilih atau dikonfigurasi. Panduan GPX offline adalah track-follow, bukan peta jalan atau turn-by-turn.
- Unlock biometrik adalah local unlock, bukan akun cloud. Login akun dan pemulihan identitas belum tersedia.
- Sinkronisasi sesi dan telemetri ke backend belum menjadi alur produksi end-to-end.
- Supabase Edge Functions untuk Gemini dan feedback serta migrasinya perlu diterapkan ke proyek nyata, dikonfigurasi, dan diuji. Paket Flutter saja tidak mengaktifkan layanan.
- SOS masih bergantung pada handoff aplikasi/kanal yang tersedia; tidak boleh disebut pesan terkirim tanpa acknowledgment kanal.
- Ledger, proof, leaderboard, wearable, dan cuaca belum punya provider/aturan produksi yang disetujui.
- Uji perangkat sasaran, build distribusi bertanda tangan, pemantauan, prosedur insiden, dan dukungan rilis belum dibuktikan.

Status ini harus diperbarui hanya dengan bukti yang dapat diulang: konfigurasi environment, hasil uji, log tanpa data sensitif, dan demonstrasi pada perangkat.

## 3. Aturan Kerja

**Product Owner:** menetapkan urutan, menerima PBI terhadap kriteria, menyetujui data/provider/retensi/biaya. **Developers:** memilih scope sesuai kapasitas dan menghasilkan increment terintegrasi. **Scrum Master:** membantu transparansi, inspeksi, dan penghilangan hambatan.

Planning menetapkan satu Sprint Goal dan PBI yang dapat selesai; Daily Scrum menyelaraskan rencana Developers; Review mendemonstrasikan increment beserta keterbatasannya; Retrospective memilih perubahan cara kerja. Jangan menetapkan tanggal produksi sebelum gerbang provider, keamanan, perangkat, dan operasi lolos.

**Definition of Ready:** hasil pengguna jelas; kriteria dapat diuji; pemilik keputusan dan dependensi diketahui; data yang diproses, izin, retensi, biaya, keadaan offline/gagal, dan platform sasaran ditentukan.

**Definition of Done:** kode terintegrasi; format, analisis, tes terkait, migrasi, serta build platform target lulus; loading/empty/offline/error/permission-denied ditangani; data sensitif dilindungi; status hanya berdasarkan acknowledgment nyata; dokumentasi deployment/rollback diperbarui; demonstrasi dan hasil uji dapat diulang. Mock, fixture, atau sekadar dependency tidak memenuhi Done untuk integrasi online.

## 4. Product Backlog v2 — Urutan Improvement

### P0 — Keterpakaian inti dan online yang jujur

| Urut | PBI                                                   | Hasil dan kriteria penerimaan                                                                                                                                                                                                           | Status                                                          |
| ---: | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
|    1 | **PB2-01 — Impor GPX dan panduan track offline**      | Geometri terenkripsi; rute bertahan restart/offline; mode panduan menampilkan track, GPS, progres, jarak tersisa, kualitas fix, dan status off-route; stop menghentikan stream/wakelock; GPX mentah tidak mengarang instruksi belok.    | Implementasi lokal dan focused tests ada; device smoke pending. |
|    2 | **PB2-02 — Basemap dan navigasi online**              | PO menyetujui provider, lisensi, biaya, attribution, kuota, cache/offline policy, dan kebijakan lokasi. Basemap, turn-by-turn, serta reroute hanya aktif bila provider nyata siap; GPX offline tetap berfungsi.                         | Blocked oleh keputusan provider.                                |
|    3 | **PB2-03 — Identitas dan konfigurasi cloud**          | Pisahkan local unlock dari akun; sediakan sign-in/out, pemulihan akun, konfigurasi environment dev/staging/prod, status `belum dikonfigurasi/offline/siap/gagal`, dan aturan sesi/token.                                                | Belum lengkap; Supabase anon untuk function bukan akun produk.  |
|    4 | **PB2-04 — Sinkronisasi sesi nyata**                  | Outbox lokal stabil; autentikasi, RLS, upload bertahap, retry idempotent, acknowledgment, konflik, logout, dan restart diuji terhadap backend staging. Item pending tidak hilang atau ditandai tersinkron sebelum server mengonfirmasi. | Blocked oleh schema, project, auth, dan kontrak sync.           |
|    5 | **PB2-05 — Integrasi online yang sudah direncanakan** | Deploy/test Edge Functions AI dan feedback pada staging; validasi secrets, kuota, RLS, rate limit, retensi, timeout, serta status remote. Rilis tetap menyebut integrasi belum tersedia bila deployment belum dilakukan.                | Kode lokal ada; deploy/runtime test pending.                    |
|    6 | **PB2-06 — Navigasi dan alur tanpa jalan buntu**      | Tiap fitur inti bisa ditemukan dari navigasi; rute kosong mengarahkan ke impor/aksi yang relevan; seluruh loading/error memiliki pemulihan; target sentuh, kontras, dan teks diuji di ukuran layar sasaran.                             | Audit E2E masih pending.                                        |

### P1 — Keandalan perangkat dan keselamatan

| Urut | PBI                                           | Hasil dan kriteria penerimaan                                                                                                                                                                              |
| ---: | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|    7 | **PB2-07 — Siklus sesi**                      | Uji start/pause/resume/stop, background/terminate/restart, GPS lemah, izin ditolak, storage penuh, dan pemulihan; data yang hilang/terestimasi diberi label.                                               |
|    8 | **PB2-08 — SOS dan kesiapan**                 | Uji batal countdown, kontak invalid, app handoff gagal, permission/lokasi tidak tersedia; tampilkan `dibuka untuk handoff` terpisah dari `terkirim`. Tidak mengklaim deteksi sebagai kepastian kecelakaan. |
|    9 | **PB2-09 — Retensi, ekspor, dan penghapusan** | Ekspor dapat dibuka ulang; data cache dipisahkan dari sesi; pengguna dapat menghapus data sesuai kebijakan; hapus akun menangani cloud/local dengan konfirmasi dan status yang jelas.                      |
|   10 | **PB2-10 — Kompatibilitas dan baterai**       | Tetapkan perangkat/OS minimum; ukur sesi panjang, background, panas, baterai, sensor hilang, dan recovery pada perangkat nyata.                                                                            |

### P2 — Integrasi tambahan setelah gerbang dasar

| Urut | PBI                              | Hasil dan prasyarat                                                                                                                                                                                            |
| ---: | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|   11 | **PB2-11 — Proof of Completion** | Pilih ledger/biaya/kontrak; consent; hash file saja; retry/status terverifikasi dari jaringan nyata; kegagalan tidak menghalangi hasil lokal. Jangan mulai publikasi sebelum threat model dan biaya disetujui. |
|   12 | **PB2-12 — Leaderboard**         | Aturan kelayakan, moderasi, identitas, privasi, anti-duplikasi, dan verifikasi proof disepakati; pending tidak pernah tampil terverifikasi.                                                                    |
|   13 | **PB2-13 — Wearable/cuaca**      | Provider dan hak akses disetujui; izin dapat dicabut; sumber/waktu/kualitas data ditampilkan; offline dan retry diuji.                                                                                         |

## 5. Sprint 12 — Release Recovery

**Sprint Goal:** hentikan kebingungan utama dan kurangi risiko kehilangan/penyajian data palsu. Jangan mengambil seluruh PB2 sekaligus; PO memilih scope yang dapat diuji.

- **PBI-12.1:** selesai lokal: geometri GPX dienkripsi dengan codec lokal, dipulihkan dari storage, dan preview rute offline dapat dibuka. Full-suite 47 tes dan `flutter analyze` lulus; verifikasi pada perangkat sasaran masih pending.
- **PBI-12.1:** increment lokal: geometri GPX dienkripsi/dipulihkan; preview; panduan foreground dengan GPS, progres, jarak tersisa, off-route sesuai akurasi, dan screen wake. Full-suite 52 tes dan `flutter analyze` lulus; device smoke masih pending. Basemap/turn-by-turn online belum tersedia tanpa provider.
- **PBI-12.2:** selesai lokal: logout membersihkan transcript AI dan membuang respons request yang datang terlambat. Sisa: integrasi dengan sign-out akun cloud setelah akun produk tersedia.
- **PBI-12.3:** buat inventaris setiap tombol/layar inti: aksi, online dependency, empty/loading/error, status data, pemulihan, dan sumber/attribution.
- **PBI-12.4:** smoke test alur GPX import → tutup/buka aplikasi → cari → buka preview dalam mode pesawat; uji GPX invalid dan geometry lama.
- **PBI-12.4:** smoke test alur GPX import → tutup/buka → cari → preview → mulai/akhiri panduan dalam mode pesawat; uji izin ditolak, GPS lemah, GPX invalid, serta geometry lama.
- **PBI-12.5:** nyatakan belum tersedia untuk map provider, akun cloud, session sync, SOS server, AI/feedback yang belum deploy, ledger dan wearable.
- **Penerimaan sprint:** jalur GPX terlihat dan bertahan offline; tidak ada status online palsu; fokus tests, analyze, full test, dan build target dicatat. Sprint belum menjadi release candidate hanya karena tes lokal lulus.

## 6. Sprint Berikutnya dan Urutan Gerbang

Sprint berikut adalah usulan urutan; kalender, estimasi, dan kapasitas ditentukan saat Planning setelah blocker provider diketahui.

### Sprint 13 — Peta dan pencarian rute online

**Goal:** pembalap bisa membandingkan track GPX dengan peta jalan online yang memiliki attribution dan fallback offline.

- Putuskan provider, lisensi, biaya, kuota, attribution, geocoding, routing, elevasi, tile cache, dan kebijakan lokasi sebelum integrasi.
- Buat adapter provider dan peta layar penuh; tampilkan lokasi/GPS, jalur tersimpan, status jaringan, sumber data, dan error provider.
- Uji GPX offline, timeout, rate limit, tile gagal, izin lokasi ditolak, dan penghapusan cache tanpa menyentuh sesi.
- Jika provider belum disetujui, jangan memakai public tile endpoint sebagai layanan produksi; pertahankan panduan GPX lokal.

### Sprint 14 — Akun cloud dan sinkronisasi

**Goal:** pengguna dapat berpindah perangkat dan mengetahui data mana yang benar-benar tersinkron.

- Tetapkan auth akun, pemulihan, sign-out, session lifetime, Supabase schema/RLS, environment staging, serta kebijakan retensi.
- Implementasikan sync outbox sesi/kontak dengan ID stabil, acknowledgment, retry idempotent, konflik, dan pemulihan setelah force-stop.
- Deploy dan uji feedback/AI functions; verifikasi secrets, consent, kuota, rate-limit, observability tanpa payload sensitif, dan deletion policy.

### Sprint 15 — Uji lapangan dan keselamatan

**Goal:** panduan dan perekaman dapat dipakai saat bersepeda tanpa status menyesatkan atau kehilangan data.

- Uji GPS fix/akurasi, keluar jalur, screen wake, background/foreground, baterai, panas, permission revoke, dan recovery pada perangkat target.
- Uji start/pause/resume/stop sesi bersamaan dengan route guidance; pastikan GPS stream/foreground service dan lifecycle tidak saling mengganggu.
- Uji SOS cancel/handoff/gagal, data sesi offline, file besar/rusak, penyimpanan penuh, ekspor, serta akses hasil setelah logout/restart.
- Turn-by-turn/reroute hanya diterima bila kontrak provider dan hasil uji nyata mendukungnya.

### Sprint 16 — Release candidate

**Goal:** menghasilkan build terbatas yang bisa dipasang, diamati, dipulihkan, dan didukung.

- Siapkan environment prod, signed build, migrasi dan rollback, backup/restore, monitoring/alert, incident/support runbook, privacy disclosure, serta batas biaya.
- Jalankan full automated tests, static analysis, integration/device matrix, accessibility dasar, instalasi baru/upgrade, dan smoke test offline/online.
- PO menerima daftar fitur aktif, belum tersedia, risiko residual, serta provider/platform yang memang telah diuji sebelum distribusi.

Perencanaan sprint memakai kapasitas aktual dan blocker nyata. PBI eksternal boleh ditunda; jangan mengganti integrasi yang belum tersedia dengan mock yang tampil seolah hasil produksi.

## 7. Release Gates — Syarat “Production Ready”

Produk hanya dapat disebut production-ready bila semua gate yang masuk scope rilis lulus:

- **Build/release:** build signed, instalasi baru dan upgrade database diuji pada OS/perangkat minimum; rollback tersedia.
- **Online:** staging dan production punya URL/key terpisah; server secrets tidak ada di bundle; auth, RLS, kuota, rate limit, migrasi dan acknowledgment diverifikasi.
- **Offline/data:** rute/session/outbox tetap ada setelah force-stop/restart; retry tidak menggandakan; status lokal/remote tepat; restore/penghapusan diuji.
- **Keselamatan:** izin ditolak/GPS lemah/handoff gagal dan pembatalan diuji; tidak ada klaim metrik/provider yang tidak didukung.
- **Privasi/keamanan:** audit data flows, consent, retensi/deletion, backup, export, logs, dependency advisories, secrets, dan akses admin.
- **Kualitas:** full automated tests, analisis, integrasi, smoke test, accessibility dasar, serta manual device matrix lulus; defect blocker/high ditutup atau dikecualikan tertulis oleh PO.
- **Operasi:** health monitoring, alert, backup/restore, incident owner, support contact, release notes, batas layanan/biaya, dan prosedur gangguan tersedia.

Jika satu gate belum memiliki bukti, catat `belum siap` dan batasi distribusi ke internal/tester; jangan membuat klaim produksi.

## 8. Transparansi Status

Setiap fitur online menggunakan istilah konsisten: `belum dikonfigurasi`, `offline`, `memuat`, `tersedia`, `pending`, `gagal`, dan `terkonfirmasi`. `Tersimpan lokal` bukan `tersinkron`; `dibuka` bukan `terkirim`; `hash dibuat` bukan `proof terverifikasi`; preview GPX bukan basemap/navigasi.
Setiap fitur online menggunakan istilah konsisten: `belum dikonfigurasi`, `offline`, `memuat`, `tersedia`, `pending`, `gagal`, dan `terkonfirmasi`. `Tersimpan lokal` bukan `tersinkron`; `dibuka` bukan `terkirim`; `hash dibuat` bukan `proof terverifikasi`; panduan track GPX bukan basemap atau turn-by-turn.

Pada Review, catat PBI selesai beserta hasil tes, platform yang diuji, environment/provider, blocker yang tersisa, serta apakah penerimaan PO terpenuhi. Velocity digunakan untuk forecast tim, bukan target individu.
