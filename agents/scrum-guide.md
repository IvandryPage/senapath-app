# Panduan Scrum dan Rencana Pengembangan Senapath

## 1. Tujuan dan Asumsi

Panduan ini menerjemahkan [requirements.md](requirements.md) menjadi backlog dan rencana sprint. Ini baseline yang dapat diubah Product Owner (PO) setelah kapasitas tim, risiko teknis, dan dependensi diketahui; bukan janji tanggal rilis.

- Asumsi: tim lintas fungsi memiliki akuntabilitas PO, Scrum Master (SM), dan Developers dengan kemampuan Flutter, backend/integrasi, QA, serta desain sesuai kebutuhan. Satu orang boleh memegang beberapa keahlian, tetapi PO dan SM tetap bertanggung jawab atas perannya.
- Asumsi jadwal: sprint dua minggu, 12 sprint (sekitar 24 minggu sejak kickoff). Tanggal kalender ditetapkan setelah tim tersedia. Sprint pertama menjadi pengukuran awal; tidak ada velocity atau kapasitas yang diasumsikan.
- Repo saat ini berupa scaffold Flutter. Backend, database, penyedia peta/kurs/cuaca/AI, kanal SOS, ledger blockchain, wearable/provider yang didukung, dan perangkat minimum belum ditentukan.
- Fitur lokal/offline dapat dikerjakan lebih awal. Integrasi eksternal hanya dijadwalkan sebagai selesai setelah penyedia, API, biaya, privasi, kredensial aman, dan lingkungan uji disepakati. Mock/adapter bukan bukti integrasi produksi.
- Estimasi story point ditetapkan tim saat refinement. Prioritas dan sprint pada tabel adalah urutan awal yang dapat disusun ulang PO.

## 2. Cara Kerja Scrum

**Peran:** PO menetapkan Product Goal, mengurutkan backlog, dan menerima hasil berdasarkan kriteria. SM memfasilitasi Scrum dan membantu menghilangkan hambatan. Developers memilih PBI, merencanakan pekerjaan, menguji, dan menghasilkan Increment. Pembalap, manajer tim, dan pemilik layanan memberi masukan pada Sprint Review.

**Acara:** Sprint Planning menentukan Sprint Goal dan PBI yang realistis; Daily Scrum 15 menit untuk Developers menyesuaikan rencana; Sprint Review mendemonstrasikan Increment kepada pemangku kepentingan; Sprint Retrospective memilih perbaikan cara kerja. Sprint dua minggu mencakup seluruh acara tersebut.

**Artefak:** Product Backlog adalah daftar terurut kebutuhan; Sprint Backlog berisi Sprint Goal, PBI terpilih, dan rencana Developers; Increment adalah hasil terintegrasi yang memenuhi Definition of Done.

**Panduan Definition of Ready:** tujuan pengguna jelas, acceptance criteria dapat diuji, risiko/dependensi diketahui, ukuran memungkinkan selesai dalam satu sprint, dan keputusan eksternal yang menghalangi sudah dibuat atau memiliki pemilik serta rencana.

**Definition of Done:** perubahan terintegrasi; analisis statis dan pengujian yang sesuai lulus; kriteria penerimaan termasuk error/offline/izin ditolak yang relevan terpenuhi; keamanan, privasi, sumber/kualitas/status data ditangani; data lokal pending tidak hilang; regresi fitur terkait diperiksa; hasil dapat didemonstrasikan dan dokumentasi/config diperbarui.

## 3. Product Goal dan Urutan Prioritas

**Product Goal:** pembalap dapat menyiapkan perjalanan, merekam dan menyimpan sesi dengan andal saat offline, menangani peringatan/SOS secara transparan, lalu meninjau atau mengekspor hasilnya. Fitur tambahan tidak boleh mengorbankan keselamatan, privasi, atau data sesi lokal.

- **P0 — inti dan keselamatan:** akun/logout, kontak darurat, kesiapan perangkat, rekam/simpan/sinkron sesi, ringkasan dan status data.
- **P1 — persiapan dan pengelolaan:** peta/rute, integrasi wearable yang didukung, sensor/peringatan, satuan, ekspor/impor, storage, profil, konversi, mini game, feedback.
- **P2 — publikasi/layanan bersyarat:** AI, SOS jaringan, blockchain, dan leaderboard. NFR keamanan, privasi, offline, keselamatan, kompatibilitas, dan transparansi tetap lintas semua prioritas.

## 4. Product Backlog: User Story

ID story memetakan langsung ke FR. Acceptance criteria di bawah berupa ringkasan; requirement asal tetap menjadi kriteria lengkap.

| Urut | ID / FR       | User story dan hasil yang dapat diterima                                                                                                                                                        | Prioritas | Sprint |
| ---: | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | -----: |
|    1 | US-01 / FR-18 | Sebagai pembalap, saya ingin navigasi utama dan logout yang menutup sesi tanpa menghapus riwayat, agar saya dapat berpindah fitur dan keluar dengan aman.                                       | P0        |    1-2 |
|    2 | US-02 / FR-07 | Sebagai pembalap, saya ingin telemetri disimpan berkala dan disinkronkan tanpa duplikasi, agar data sesi tersedia offline dan setelah aplikasi dibuka kembali.                                  | P0        |    3-4 |
|    3 | US-03 / FR-06 | Sebagai pembalap, saya ingin memulai, menjeda, melanjutkan, dan mengakhiri sesi serta melihat status/metrik, agar perekaman mudah dikendalikan.                                                 | P0        |      3 |
|    4 | US-04 / FR-20 | Sebagai pembalap, saya ingin memeriksa izin, GPS, dan sensor sebelum mulai, agar saya tahu dampaknya pada perekaman.                                                                            | P0        |      3 |
|    5 | US-05 / FR-13 | Sebagai pembalap, saya ingin melihat ringkasan sesi dengan data hilang atau estimasi ditandai, agar hasil ditinjau secara tepat.                                                                | P0        |      4 |
|    6 | US-06 / FR-19 | Sebagai pembalap, saya ingin mengelola 1-3 kontak darurat secara aman, agar SOS menggunakan kontak valid.                                                                                       | P0        |   2, 5 |
|    7 | US-07 / FR-10 | Sebagai pembalap, saya ingin membatalkan countdown insiden atau mengirim SOS manual dan melihat statusnya, agar kegagalan jaringan tidak tersamarkan.                                           | P0        |      5 |
|    8 | US-08 / FR-01 | Sebagai pembalap, saya ingin masuk dengan biometrik dan pemulihan aman, agar sesi lokal hanya dapat dibuka dengan benar.                                                                        | P0        |      2 |
|    9 | US-09 / FR-04 | Sebagai pembalap, saya ingin mencari rute, melihat elevasi/POI, dan membuka rute tersimpan offline, agar perjalanan dapat direncanakan.                                                         | P1        |      6 |
|   10 | US-10 / FR-08 | Sebagai pembalap, saya ingin melihat sumber dan kualitas metrik sensor, agar estimasi tidak disalahartikan sebagai pengukuran pasti.                                                            | P1        |      4 |
|   11 | US-11 / FR-09 | Sebagai pembalap, saya ingin mengatur peringatan lokal dan mengetahui keterbatasan informasi online, agar pengingat berguna saat offline.                                                       | P1        |      5 |
|   12 | US-12 / FR-21 | Sebagai pembalap, saya ingin memilih metrik/imperial di semua tampilan tanpa mengubah nilai dasar, agar metrik konsisten.                                                                       | P1        |   2, 4 |
|   13 | US-13 / FR-22 | Sebagai pembalap, saya ingin ekspor sesi ke GPX/JSON dan impor rute GPX, agar data dapat digunakan di luar aplikasi dan rute ditinjau.                                                          | P1        |      7 |
|   14 | US-14 / FR-23 | Sebagai pembalap, saya ingin melihat storage, menghapus cache peta, dan mengatur batas unduhan tanpa kehilangan sesi.                                                                           | P1        |      7 |
|   15 | US-15 / FR-16 | Sebagai pembalap, saya ingin melihat/memperbarui profil dan foto agar informasi akun relevan.                                                                                                   | P1        |      2 |
|   16 | US-16 / FR-02 | Sebagai manajer tim, saya ingin konversi mata uang dan anggaran beberapa item dengan kurs transparan, agar biaya logistik dapat dibandingkan.                                                   | P1        |      8 |
|   17 | US-17 / FR-03 | Sebagai manajer tim, saya ingin mengonversi jadwal ke London, WIB, WITA, dan WIT dengan tanggal lokal, agar waktu lintas zona tepat.                                                            | P1        |      8 |
|   18 | US-18 / FR-11 | Sebagai pembalap, saya ingin tes reaksi dua menit dengan skor bertanggal tersimpan lokal, agar hasil tetap tersedia dan dapat dibandingkan.                                                     | P1        |      9 |
|   19 | US-19 / FR-05 | Sebagai pembalap, saya ingin saran strategi dari konteks yang tersedia, agar persiapan terbantu tanpa menganggapnya sebagai jaminan keselamatan.                                                | P2        |     10 |
|   20 | US-20 / FR-12 | Sebagai pembalap, saya ingin ringkasan tren tes reaksi dan pengingat istirahat bila AI tersedia, agar skor menjadi konteks, bukan penentu kelayakan.                                            | P2        |     10 |
|   21 | US-21 / FR-14 | Sebagai pembalap, saya ingin opt-in pendaftaran hash ringkasan dan status transaksi, agar integritas berkas dapat diperiksa tanpa mempublikasikan data pribadi.                                 | P2        |     11 |
|   22 | US-22 / FR-15 | Sebagai pembalap, saya ingin melihat peringkat dan status verifikasi, agar hasil pending tidak tampak terverifikasi.                                                                            | P2        |     11 |
|   23 | US-23 / FR-17 | Sebagai pengguna, saya ingin mengirim saran/kesan dan melihat hasil pengiriman, agar masukan tercatat atau kegagalannya diketahui.                                                              | P1        |     11 |
|   24 | US-24 / FR-24 | Sebagai pembalap, saya ingin menghubungkan wearable yang didukung dan menyinkronkan metrik dengan izin saya, agar data latihan dapat ditinjau bersama sesi dengan sumber dan status yang jelas. | P1        |      6 |

### PBI lintas fungsi untuk NFR

| ID   | NFR    | Pekerjaan dan bukti penerimaan                                                                                                          |
| ---- | ------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Q-01 | NFR-01 | Gunakan secure storage/enkripsi platform untuk data sensitif; tinjau logout dan log; pastikan API key tidak tertanam di aplikasi klien. |
| Q-02 | NFR-02 | Minta izin/persetujuan sebelum akses lokasi, sensor, foto, wearable, SOS, proof, atau publikasi; jelaskan data dan tujuan pembagian.    |
| Q-03 | NFR-03 | Uji rekam/simpan, pembatalan alarm, dan buka rute tersimpan dalam mode pesawat; kegagalan online tidak menghapus data lokal.            |
| Q-04 | NFR-04 | Sinkronisasi dapat dilanjutkan, idempotent, tidak menduplikasi, dan mempertahankan data lokal sampai server mengonfirmasi.              |
| Q-05 | NFR-05 | Kontrol sesi mudah dikenali; interaksi saat bersepeda minimal; peringatan penting jelas dibedakan.                                      |
| Q-06 | NFR-06 | Uji izin ditolak, GPS lemah, sensor/wearable tidak tersedia atau berbeda dukungan, latar belakang, dan baterai pada perangkat sasaran.  |
| Q-07 | NFR-07 | Tampilkan sumber/waktu kurs, kualitas dan sumber metrik termasuk wearable, status offline/sinkron, status SOS, dan status ledger.       |

## 5. Jadwal Sprint

Asumsi dua minggu per sprint. Minggu dihitung sejak kickoff; tanggal kalender ditetapkan kemudian.

| Sprint | Minggu | Sprint Goal dan scope                                                                                             |
| -----: | -----: | ----------------------------------------------------------------------------------------------------------------- |
|      1 |    1-2 | Fondasi delivery, navigasi dasar, keputusan arsitektur dan risiko.                                                |
|      2 |    3-4 | Identitas, logout, profil, kontak darurat, keamanan dan preferensi dasar.                                         |
|      3 |    5-6 | Pemeriksaan kesiapan, kontrol sesi, GPS dan penyimpanan lokal berkala.                                            |
|      4 |    7-8 | Kualitas sensor, ringkasan, unit lintas tampilan, status sinkronisasi.                                            |
|      5 |   9-10 | Peringatan, countdown/batal, SOS manual/otomatis dan status pengiriman.                                           |
|      6 |  11-12 | Integrasi wearable/provider yang dipilih, serta peta/rute, elevasi, POI dan rute offline sesuai kapasitas sprint. |
|      7 |  13-14 | Impor/ekspor GPX/JSON, penggunaan storage dan pembersihan cache aman.                                             |
|      8 |  15-16 | Konversi kurs/anggaran dan zona waktu dengan DST.                                                                 |
|      9 |  17-18 | Mini game reaksi, skor lokal bertanggal dan perbandingan.                                                         |
|     10 |  19-20 | Saran AI/tren jika penyedia disetujui; jika tidak, ambil P1 siap.                                                 |
|     11 |  21-22 | Feedback, proof opt-in, transaksi dan leaderboard dengan status verifikasi.                                       |
|     12 |  23-24 | Hardening, uji end-to-end/perangkat, keamanan, offline dan release candidate.                                     |

## 6. Sprint Backlog: PBI dan Pekerjaan

Developers memilih PBI berdasarkan kapasitas pada Sprint Planning dan memecah task lebih lanjut. Setiap PBI mewarisi acceptance criteria story serta Definition of Done.

### Sprint 1 — Fondasi aplikasi

**Goal:** siapkan jalur delivery dan keputusan minimum untuk membuka pengembangan inti.

- **PBI-1.1, navigasi (US-01/FR-18):** buat shell dan rute/tab utama; sediakan layar awal, loading, kosong, dan error; demonstrasikan perpindahan fitur.
- **PBI-1.2, kualitas build:** tetapkan lint/format, strategi unit/widget/integration test, build platform yang tersedia, dan pemeriksaan otomatis.
- **PBI-1.3, keputusan teknis:** tetapkan batas UI/domain/data dan implementasi Drift (schema/migrasi); catat Supabase sebagai cloud database terpilih; rincikan project config, schema/RLS, model akun, sinkronisasi, perangkat sasaran, dan pemilik blocker.
- **PBI-1.4, baseline privasi (Q-01/Q-02):** petakan data sensitif dan aliran data; cegah token, lokasi rinci, kontak, dan isi SOS masuk log.
- **Penerimaan:** aplikasi dapat dibangun dan navigasi dasar berjalan; keputusan serta dependensi memiliki pemilik. Mock bukan fitur produksi.

### Sprint 2 — Identitas dan data pengguna

**Goal:** pengguna dapat mengakses aplikasi dan mengelola profil/kontak dengan aman.

- **PBI-2.1 (US-08/FR-01):** gunakan biometrik sebagai local device-unlock; hanya buka aplikasi saat sukses; sediakan fallback kredensial layar-kunci OS; uji penolakan, pembatalan dan perangkat tanpa biometrik. Ini belum merupakan login akun Supabase.
- **PBI-2.2 (US-01/FR-18):** invalidasi sesi saat logout; pastikan sesi tidak dapat dipakai lagi dan riwayat tetap ada.
- **PBI-2.3 (US-15/FR-16):** lihat/edit bidang profil yang diizinkan; pilih foto dengan izin dan simpan terenkripsi di app-private storage; tangani pembatalan dan kegagalan.
- **PBI-2.4 (US-06/FR-19):** tambah/edit/hapus 1-3 kontak; validasi input dan batas maksimum; lindungi data lokal. Tandai perubahan lokal sebagai pending sampai konfigurasi Supabase, schema/RLS, dan sync tersedia; jangan tampilkan sebagai sudah tersinkron.
- **PBI-2.5 (US-12/FR-21, Q-01/Q-02):** simpan preferensi satuan dan gunakan formatter bersama; gunakan secure storage/enkripsi yang diputuskan.
- **Penerimaan:** biometrik gagal tidak membuka sesi; logout aman; batas kontak berlaku; nilai domain tidak disimpan dalam format tampilan.

### Sprint 3 — Kesiapan dan perekaman inti

**Goal:** pembalap dapat memeriksa perangkat dan merekam sesi lokal.

- **PBI-3.1 (US-04/FR-20):** minta izin lokasi; periksa status notifikasi, GPS fix, dan ketersediaan accelerometer/gyroscope; bedakan izin ditolak dari sensor tak tersedia; jelaskan opsi lanjut terbatas.
- **PBI-3.2 (US-03/FR-06):** implementasi state mulai/jeda/lanjut/akhiri; cegah transisi invalid; tampilkan status rekam dan metrik tersedia.
- **PBI-3.3 (US-02/FR-07):** rekam lokasi/waktu dengan izin; hitung metrik dasar; simpan berkala dan pulihkan setelah aplikasi dibuka ulang.
- **PBI-3.4 (US-02, Q-03/Q-04):** tetapkan ID sesi stabil, schema/migrasi Drift, status `pending`, penyimpanan koordinat terenkripsi, dan aturan agar data belum dikonfirmasi tetap tersimpan.
- **PBI-3.5:** uji mode pesawat, izin lokasi ditolak, GPS lemah, dan aplikasi ditutup saat sesi aktif.
- **Penerimaan:** sesi dapat dijeda/dilanjutkan/dihentikan dan dipulihkan offline; dampak GPS lemah terlihat.

### Sprint 4 — Sensor, ringkasan, dan unit

**Goal:** metrik dan ringkasan dapat dipercaya serta konsisten satuannya.

- **PBI-4.1 (US-10/FR-08):** GPS sebagai sumber lokasi utama; rekam barometer, accelerometer, dan gyroscope bila tersedia; tampilkan sumber/cakupan kualitas; jangan klaim cadence/lean angle tervalidasi tanpa validasi.
- **PBI-4.2 (US-05/FR-13):** ringkasan jarak, durasi, elevasi dan grafik bila data cukup; tandai sumber/estimasi atau data tidak tersedia; buka ringkasan dan riwayat secara offline.
- **PBI-4.3 (US-12/FR-21):** terapkan metrik/imperial pada sesi aktif, ringkasan, dan riwayat tanpa mengubah nilai dasar; tampilan peta mengikuti preferensi saat fitur peta tersedia.
- **PBI-4.4 (US-02, Q-04/Q-07):** tampilkan status lokal/pending; pertahankan data sampai Supabase dikonfigurasi dan mengonfirmasi sinkronisasi; retry cloud belum aktif pada sprint ini.
- **PBI-4.5:** uji sensor tak tersedia, sampel buruk, aplikasi latar belakang, dan konsumsi baterai awal.
- **Penerimaan:** ringkasan offline tersedia dan label estimasi/sumber tampil; sampel minim ditandai; belum ada data yang disebut tersinkron sebelum konfirmasi cloud.

### Sprint 5 — Peringatan dan SOS

**Goal:** alarm dapat dibatalkan dan status SOS jelas saat jaringan berhasil maupun gagal.

- **PBI-5.1 (US-07/FR-10):** SOS manual dengan countdown 15 detik; pembatalan menghentikan handoff; gunakan bahasa “potensi insiden”, bukan kepastian. Deteksi otomatis belum diaktifkan sampai algoritme dan kanal disetujui.
- **PBI-5.2 (US-06/US-07, FR-10/FR-19):** validasi kontak; tombol telepon membuka dialer; tombol WhatsApp membuka draft pesan berisi SOS dan lokasi terakhir. Status dibedakan antara aplikasi dibuka untuk handoff dan pesan benar-benar terkirim; pengguna tetap menekan Kirim.
- **PBI-5.3 (US-11/FR-09):** atur jenis, volume/frekuensi; jadwalkan peringatan lokal offline; tandai informasi online kedaluwarsa/tidak tersedia.
- **PBI-5.4 (Q-02/Q-03/Q-05/Q-07):** uji pembatalan, WhatsApp/dialer tidak tersedia, nomor invalid, lokasi terakhir tidak ada, dan status handoff/pengiriman.
- **Penerimaan:** cancel tidak membuka WhatsApp; handoff tidak diklaim sebagai pesan terkirim; kontak invalid ditolak; status keterbatasan kanal jelas.

### Sprint 6 — Peta, rute, dan POI

**Goal:** rute dapat dicari, ditinjau, dan dibuka offline.

- **PBI-6.1 (US-09/FR-04):** catat keputusan provider/format tile, geocoding, elevasi, cache, lisensi dan biaya; jangan hardcode rahasia. Sampai provider dipilih, implementasi memakai boundary repository yang provider-agnostic.
- **PBI-6.2:** implementasi pencarian rute tersimpan lokal dengan hasil, kosong, loading, dan error yang jelas.
- **PBI-6.3:** tampilkan metadata elevasi/POI nutrisi/medis bila tersedia dan tandai sumber/waktu data.
- **PBI-6.4 (NFR-03):** simpan route metadata di Drift dan buka dalam mode offline; geometry/map tile belum diklaim tersedia sebelum provider peta dipilih.
- **PBI-6.5:** uji layanan gagal, cache kosong/penuh, unduhan terputus, kuota dan perangkat sasaran.
- **PBI-6.6 (US-24/FR-24):** setelah provider dipilih dan aksesnya disetujui, implementasikan koneksi/otorisasi dan pemutusan akses; petakan hanya metrik yang didukung; tampilkan sumber/waktu/status; sinkronkan dengan ID stabil dan cegah duplikasi; uji izin dicabut, offline, dan retry. Sinkronisasi real-time hanya masuk cakupan bila API/perangkat benar-benar mendukungnya.
- **Penerimaan:** rute tersimpan dan metadata dapat dicari offline; layar kosong tidak menyamarkan kegagalan pencarian; provider peta yang belum dipilih tidak ditampilkan seolah tersedia.

### Sprint 7 — Berkas dan storage

**Goal:** data dapat dipindahkan tanpa mengorbankan riwayat atau sinkronisasi pending.

- **PBI-7.1 (US-13/FR-22):** impor GPX melalui file selector; parse XML terstruktur dan validasi titik; tolak berkas rusak/tidak didukung; simpan metadata rute sebagai offline.
- **PBI-7.2:** ekspor sesi ke GPX/JSON melalui dialog save OS; JSON memakai `schemaVersion`; tangani pembatalan/gagal tulis dan validasi GPX hasil ekspor.
- **PBI-7.3 (US-14/FR-23):** hitung penggunaan database dan directory cache peta secara terpisah; tampilkan batas offline.
- **PBI-7.4:** hapus hanya directory cache peta/atur batas unduhan berikutnya; jangan hapus database Drift, sesi, riwayat atau antrean pending.
- **PBI-7.5 (Q-03/Q-04):** uji berkas rusak/besar, storage penuh, pembatalan ekspor dan pembersihan saat sesi pending.
- **Penerimaan:** GPX hasil ekspor dapat diparse kembali; GPX invalid ditolak; pembersihan cache tidak menghapus data sesi pending.

### Sprint 8 — Konversi logistik

**Goal:** konversi biaya dan waktu transparan serta benar lintas zona.

- **PBI-8.1 (US-16/FR-02):** provider kurs; konversi EUR ke IDR/USD/CHF; tampilkan sumber/waktu; kurs cache jelas bukan real-time.
- **PBI-8.2:** tambah/edit/hapus item anggaran (nama, nominal, mata uang); hitung total tujuan; sepakati pembulatan dan kurs yang tidak tersedia.
- **PBI-8.3 (US-17/FR-03):** konversi tanggal/waktu sumber ke London, WIB, WITA, WIT memakai database zona waktu; uji DST dan pergantian tanggal.
- **PBI-8.4 (NFR-03/NFR-07):** uji offline, timeout, respons rusak, kurs kedaluwarsa, waktu ambigu; tampilkan keterbatasan.
- **Penerimaan:** kurs gagal tidak disebut real-time; budget editable; tanggal hasil konversi lolos kasus DST.
- **Status increment lokal:** budget dan konversi nominal EUR memakai kurs manual yang tersimpan beserta waktu input; provider otomatis tetap terbuka sampai dipilih dan disetujui. Konversi waktu memakai database IANA dan menangani jam DST yang hilang/berulang.

### Sprint 9 — Mini game reaksi

**Goal:** tes reaksi dua menit dan hasil bertanggal bertahan secara lokal.

- **PBI-9.1 (US-18/FR-11):** indikator visual, timer dua menit, catat waktu reaksi dan respons benar/salah; cegah input ganda/tidak valid.
- **PBI-9.2:** simpan hasil dan timestamp otomatis; tampilkan riwayat/perbandingan; pulihkan setelah aplikasi dibuka ulang dan offline.
- **PBI-9.3 (Q-03/Q-04):** bila sinkronisasi tersedia, statuskan hasil dan retry idempotent; lokal tetap tersimpan sampai konfirmasi.
- **PBI-9.4:** uji interupsi aplikasi, timer, konsistensi penyimpanan dan interpretasi skor.
- **Penerimaan:** hasil lokal tidak hilang; skor tidak digunakan sendiri untuk menentukan kelayakan balapan.
- **Status increment lokal:** game visual berjalan dua menit; respons terlalu awal, waktu reaksi, dan rata-rata dicatat. Hasil selesai tersimpan offline di Drift dengan status `pending`; sesi yang dibatalkan/terputus tidak menghasilkan skor.

### Sprint 10 — AI strategi dan tren

**Goal:** AI hanya menambah konteks dengan izin dan keterbatasan yang terlihat.

- **PBI-10.1 (US-19/US-20, FR-05/FR-12):** provider Gemini melalui Supabase Edge Function; batasi biaya, jelaskan retensi/data yang dikirim, dan wajibkan persetujuan sebelum request.
- **PBI-10.2:** kirim hanya data tersedia/diizinkan; saran strategi menyebut data kurang dan kegagalan layanan; bukan diagnosis/jaminan keselamatan.
- **PBI-10.3:** rangkum tren game dan sarankan istirahat; jangan simpulkan kelayakan dari skor tunggal.
- **PBI-10.4 (Q-02/Q-03/Q-07):** uji offline, timeout dan respons tidak valid; fallback tidak tampak sebagai keluaran AI.
- **Penerimaan:** sumber/limitasi dan persetujuan jelas; jawaban gagal/offline tidak disamarkan sebagai keluaran AI; tidak ada penilaian kelayakan balapan.
- **Status increment lokal:** tersedia layar chat dan Supabase gateway ke Gemini; pengiriman butuh consent, rute/preferensi hanya ikut bila dipilih, dan kuota dibatasi 30 request per akun anonim per hari. Chat tidak disimpan sebagai riwayat lokal. Tren game tetap lokal dan membutuhkan enam hasil berskor; pengingat istirahat umum bukan keluaran AI. Backend belum aktif sampai kredensial proyek, anonymous sign-in, secret Gemini, migrasi kuota, dan Edge Function dikonfigurasi/deploy.
- **Tambahan iterasi:** kurs referensi EUR ke IDR/USD/CHF dapat diperbarui dari Frankfurter; sumber dan tanggal kutipan ditampilkan. Datanya harian, bukan harga real-time intraday; kurs manual tersimpan menjadi fallback offline.

### Sprint 11 — Feedback, proof, leaderboard

**Goal:** publikasi opt-in dapat ditelusuri tanpa mengekspos data pribadi atau status palsu.

- **PBI-11.1 (US-23/FR-17):** formulir feedback; jelaskan kebutuhan jaringan; tampilkan berhasil/gagal dan cegah kirim ganda.
- **PBI-11.2 (US-21/FR-14):** persetujuan eksplisit; hitung hash ringkasan/berkas; kirim hash saja; simpan referensi/status pending/berhasil/gagal dan sediakan retry.
- **PBI-11.3 (NFR-01/NFR-02):** pastikan data pribadi/rute rinci tidak masuk ledger; jelaskan proof membuktikan integritas berkas, bukan kejadian fisik.
- **PBI-11.4 (US-22/FR-15):** definisikan aturan kelayakan; bedakan pending, belum sinkron, belum terverifikasi, dan terverifikasi; sediakan cek proof bila ada.
- **PBI-11.5 (Q-04/Q-07):** uji batal persetujuan, gagal jaringan, retry, referensi invalid, serta privasi.
- **Penerimaan:** pending tidak tampil terverifikasi; gagalnya ledger tidak memblokir ringkasan lokal.

### Sprint 12 — Hardening dan release candidate

**Goal:** alur utama aman, tangguh, dapat diuji, dan sesuai cakupan integrasi yang benar-benar siap.

- **PBI-12.1:** uji end-to-end akun/logout, persiapan, rekam offline, restart aplikasi, sinkron, ringkasan, ekspor, batal SOS, dan rute offline.
- **PBI-12.2 (Q-02/Q-06):** uji perangkat minimum, izin ditolak, GPS lemah, sensor hilang, notifikasi ditolak, background, dan baterai.
- **PBI-12.3 (Q-01/Q-02):** audit penyimpanan, log, izin, persetujuan, konfigurasi rahasia, ekspor, dan data yang dibagikan.
- **PBI-12.4 (Q-03/Q-04/Q-07):** uji koneksi putus-pulih berulang; buktikan tidak ada kehilangan/duplikasi dan status dapat diketahui.
- **PBI-12.5 (Q-05):** tinjau kontras, target sentuh, status/alarm, dan beban interaksi selama sesi.
- **PBI-12.6:** perbaiki defect rilis, validasi build distribusi, dokumentasikan fitur/provider yang belum tersedia dan prosedur dukungan.
- **Penerimaan:** release candidate lolos gerbang kualitas; integrasi yang belum siap dinyatakan belum tersedia, bukan seolah produksi.

## 7. Dependensi dan Gerbang Keputusan

| Keputusan                                                           | Dibutuhkan sebelum | Jika belum diputuskan                                                                                                                    |
| ------------------------------------------------------------------- | -----------------: | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Supabase project, schema/RLS, auth, sinkronisasi dan retensi        |         Sprint 2-4 | Cloud database sudah dipilih/project dibuat; URL/key, schema/RLS, dan sync belum dikonfigurasi, jadi data lokal tetap pending.           |
| Implementasi Drift, enkripsi dan migrasi                            |         Sprint 2-3 | Drift sudah dipilih; schema, perlindungan data, migrasi dan uji pemulihan harus diselesaikan sebelum penyimpanan sesi/kontak diandalkan. |
| Provider peta, elevasi, format offline dan lisensi                  |           Sprint 6 | Integrasi nyata belum dapat divalidasi.                                                                                                  |
| Sumber kurs dan interval pembaruan/cache                            |           Sprint 8 | Fixture bukan kurs terkini.                                                                                                              |
| Zona waktu dan aturan DST                                           |           Sprint 8 | Gunakan database zona waktu, bukan offset tetap/manual.                                                                                  |
| Provider AI/cuaca, biaya, retensi dan persetujuan                   |          Sprint 10 | Jangan kirim data pengguna; AI tetap backlog.                                                                                            |
| Kanal SOS, format pesan dan retry                                   |           Sprint 5 | Alur lokal dapat diuji, tetapi pengiriman nyata belum selesai.                                                                           |
| Provider wearable (misalnya Garmin), akses API/SDK, izin dan metrik |           Sprint 6 | Integrasi koneksi nyata menunggu persetujuan/akses provider; jangan klaim semua merek atau real-time didukung.                           |
| Jaringan/ledger, biaya dan aturan leaderboard                       |          Sprint 11 | Proof/leaderboard menunggu keputusan; jangan kirim data ke ledger belum dipilih.                                                         |
| Perangkat sasaran dan validasi sensor                               |         Sprint 3-5 | Metrik tanpa validasi hanya data terbatas/estimasi.                                                                                      |

## 8. Pengukuran dan Penyesuaian

- Pada setiap Planning, Developers memilih scope menurut kapasitas aktual; Sprint Goal lebih penting daripada memaksakan semua PBI pada tabel jadwal.
- Gunakan velocity aktual setelah beberapa sprint hanya untuk forecast, bukan target individu atau perbandingan antartim.
- Tinjau kehilangan/duplikasi data, kegagalan offline, defect keselamatan, status menyesatkan, dan privasi sebagai sinyal kualitas utama.
- PO boleh memecah, mengestimasi, menambah, atau menjadwalkan ulang backlog berdasarkan Sprint Review dan gerbang dependensi.
- PBI yang belum memenuhi Definition of Done kembali ke Product Backlog dan tidak dihitung selesai.
