# Scrum Guide dan Product Backlog — Senapath

## 1. Visi Produk

**Senapath adalah cycling companion untuk cyclist latihan dan balap: siapkan rute dan sesi, rekam perjalanan dengan andal, lalu pahami progres dari data aktivitas yang transparan.**

Siklus inti produk adalah **persiapan rute → ride capture → ride review/progress**. Rekaman lokal, pemulihan sesi, peta/LBS, ringkasan yang benar, riwayat, dan statistik progres adalah nilai utama. Sinkronisasi cloud memperluas akses, tetapi tidak menjadi syarat untuk merekam atau melihat data lokal. Seluruh fitur harus menjelaskan asal, status, kualitas, consent, dan keterbatasan data.

**Product Goal:** cyclist dapat merekam sesi latihan/balap dari awal hingga selesai tanpa kehilangan data pada perangkat yang didukung, membuka kembali sesi secara offline, serta meninjau ringkasan dan progres yang dapat ditelusuri ke aktivitas sumber. Google OAuth, biometrik lokal, Supabase, sensor, peta, dan fitur ekstensi melengkapi alur ini tanpa menghalangi ride capture.

Target platform, perangkat sepeda yang didukung, provider kurs/cuaca, biaya, serta lingkungan deployment harus diputuskan sebelum integrasi. Rencana sprint di bawah adalah urutan usulan, bukan komitmen tanggal. Tile OpenStreetMap digunakan online dengan atribusi; penggunaan produksi, geocoding, dan routing tetap memerlukan evaluasi kebijakan/provider.

## 2. Konsep dan Batasan Produk

### Pengalaman inti

1. Cyclist menyiapkan sesi dan rute; peta tetap dapat dibuka sebelum ada GPX dan lokasi hanya diminta saat dibutuhkan.
2. Cyclist memulai rekaman dengan kontrol ringkas. Sampel lokasi/sensor yang tersedia ditandai sumber dan kualitasnya, disimpan lokal, dan tetap direkam saat layar mati sesuai kapabilitas platform/izin.
3. Setelah sesi, cyclist melihat ringkasan, membuka jejak pada peta, menelusuri riwayat, dan memahami agregat progres melalui sesi pembentuknya.
4. Login Google/Supabase dan biometrik menjaga akun/perangkat; akun cloud tidak menjadi prasyarat perekaman offline.
5. Logistik (kurs dan waktu dunia), AI analitik non-generatif, LLM percakapan, sensor, notifikasi, dan integrasi wearable mendukung perjalanan/latihan dengan data dan status yang transparan.
6. Tantangan strategi, leaderboard opt-in, serta proof blockchain adalah ekstensi opsional; kegagalannya tidak boleh mengganggu rekaman atau ringkasan lokal.

### Navigasi utama

Bottom navigation yang diusulkan:

| Tab | Isi utama |
| --- | --- |
| **Beranda** | Feed aktivitas cyclist, progres ringkas, status rekaman/sinkronisasi, peta, dan aksi utama. |
| **Jelajah** | Pencarian tempat/rute, hasil yang dapat dipilih, detail, simpan rencana. |
| **Sesi** | Mulai/jeda/lanjutkan/akhiri sesi, peta/LBS, status sensor/lokasi, detail dan ringkasan. |
| **Logistik / Tools** | Kurs mata uang dan waktu dunia untuk perjalanan/event; ekstensi companion yang tidak muat di alur inti. |
| **Profil** | Akun, preferensi, izin, privasi, **Saran dan Kesan — Mata Kuliah Pemrograman Aplikasi Mobile**, penghapusan data, dan **Logout**. |

Gunakan label konsisten antara dokumen dan UI aktual. Aktivitas, ringkasan, dan persiapan rute tidak boleh tersembunyi di balik daftar menu generik. Logout bukan pengganti penghapusan akun atau data.

### Batasan keselamatan, privasi, dan kejujuran produk

- Google OAuth menggunakan alur resmi, TLS untuk komunikasi, validasi token di backend, serta penyimpanan token/session dengan mekanisme aman platform. Aplikasi tidak meminta atau menyimpan kata sandi Google.
- Biometrik adalah **local unlock** setelah akun terautentikasi, bukan metode login cloud dan bukan pengganti pemulihan akun. Harus ada fallback PIN/kredensial perangkat sesuai kebijakan platform.
- Enkripsi saat transit dan penyimpanan token adalah syarat dasar. Enkripsi database lokal at-rest dan manajemen kuncinya harus dibuktikan pada platform sasaran sebelum data sensitif dinyatakan terlindungi; jangan mengklaimnya hanya karena aplikasi memakai Supabase atau secure storage.
- Data lokasi dan sensor bersifat sensitif: minta izin saat relevan, kumpulkan seperlunya, batasi retensi, sediakan penghapusan/ekspor, dan jangan masukkan koordinat mentah ke log, analitik, prompt LLM, atau blockchain secara default.
- Rute dan sesi inti harus tetap dapat dibaca lokal tanpa jaringan. Status **tersimpan lokal**, **menunggu sinkronisasi**, dan **terkonfirmasi server** harus berbeda.
- Mini-game hanya untuk kondisi diam/aman; nonaktifkan atau tampilkan peringatan yang jelas jika sesi perjalanan sedang direkam. Tidak mendorong pengguna berinteraksi dengan layar saat bergerak.
- AI untuk klasifikasi/rekomendasi dan LLM generatif adalah dua fitur, pipeline, kriteria evaluasi, dan label UI yang terpisah.
- Blockchain bukan database perjalanan: simpan hash/bukti minimal saja setelah consent; jangan mencatat lokasi pribadi atau data akun on-chain. Tanpa jaringan/acknowledgment tidak boleh menyatakan proof terverifikasi.
- Push notification harus opt-in, dapat dimatikan per kategori, dan tidak memuat data lokasi sensitif di teks notifikasi.

## 3. Baseline dan Asumsi Implementasi

Repository saat ini mencakup Flutter app, perekaman sesi lokal, impor/ekspor GPX/JSON, ringkasan, sinkronisasi ringkasan dengan consent, login email/Google, local unlock biometrik, fitur logistik, feedback, AI chat, dan mini-game strategi lokal. Keberadaan kode/UI bukan bukti integrasi provider, akurasi data, atau perilaku background sudah lulus pada semua environment.

Status yang perlu diverifikasi lagi sebelum planning:

- Gateway dan callback Google OAuth melalui Supabase tersedia di aplikasi; provider credentials/redirect allow-list pada dashboard dan pengujian live di project/perangkat nyata masih harus diverifikasi sebelum dinyatakan siap.
- Login biometrik yang sudah ada merupakan local unlock; bukan Google login atau autentikasi backend.
- Sinkronisasi ringkasan sesi ke Supabase meminta consent dan memakai upsert idempoten; migrasi/RLS live belum diverifikasi dan raw GPS/telemetry belum tersinkron.
- Basemap OpenStreetMap online ditampilkan di Beranda/Jelajah dan pada preview/panduan GPX; pusat awal peta saat ini Yogyakarta. Tile perlu internet; geocoding, pencarian rute online, turn-by-turn, dan provider tile produksi belum tersedia/diputuskan.
- Konversi waktu kini memakai database zona waktu IANA lokal yang dapat dicari, termasuk penanganan waktu DST hilang/berulang; konversi kurs tetap hanya referensi harian/manual, bukan kurs live.
- Chat AI atau package/model lokal bukan bukti deployment LLM maupun AI ML yang tervalidasi.
- Feed aktivitas, peta Beranda/Jelajah, dan mini-game strategi lokal telah memiliki UI; hal itu tidak membuktikan kualitas produksi, akurasi ride capture background, insight progres, integrasi push, AI analitik, atau proof blockchain.
- Build distribusi, perangkat sasaran, pemantauan, pemulihan, serta dukungan rilis perlu memiliki bukti yang dapat diulang.

Perbarui baseline ini hanya berdasarkan demonstrasi, konfigurasi yang aman, hasil tes, dan bukti deployment. Jangan menandai item selesai hanya karena UI, dependency, mock, atau fungsi lokal tersedia.

## 4. Peran dan Cara Kerja Scrum

- **Product Owner (PO):** memaksimalkan nilai produk, menetapkan urutan backlog, memutuskan provider/biaya/retensi, serta menerima hasil berdasarkan kriteria.
- **Developers:** menyepakati cara dan scope yang realistis, membangun increment terintegrasi, menguji, dan menjaga transparansi status.
- **Scrum Master:** membantu Scrum berjalan efektif, menghilangkan hambatan, dan memastikan inspeksi/adaptasi menghasilkan tindakan nyata.

Setiap Sprint Planning menetapkan Sprint Goal dan memilih PBI siap berdasarkan kapasitas aktual, bukan mengambil seluruh backlog. Daily Scrum adalah inspeksi rencana Developers. Sprint Review mendemonstrasikan increment dan keterbatasan yang masih ada kepada stakeholder. Retrospective memilih perbaikan proses untuk Sprint berikutnya.

### Definition of Ready

PBI siap diambil jika:

- persona, kebutuhan, dan hasil yang ingin dicapai jelas;
- acceptance criteria dapat diuji dan mencakup keadaan sukses, kosong, loading, offline, gagal, serta izin ditolak;
- dependensi, pemilik keputusan, provider, platform, biaya/kuota, dan data yang diproses diketahui;
- consent, retensi, penghapusan, risiko keselamatan/privasi, serta fallback telah dibahas;
- data kontrak API/schema dan strategi migrasi diketahui bila diperlukan.

### Definition of Done

PBI selesai jika:

- perubahan terintegrasi, diformat, dianalisis statis, dan tes relevan lulus;
- alur loading/empty/offline/error/permission-denied dan pemulihannya diuji;
- perubahan schema punya migrasi yang dapat diuji; API punya validasi, otorisasi, timeout, dan penanganan kegagalan;
- data sensitif, izin, session, log, dan penghapusan memenuhi kriteria PBI;
- alur cyclist diuji end-to-end: persiapan → rekaman termasuk lifecycle layar mati pada perangkat sasaran → ringkasan/riwayat/progres yang cocok dengan sesi sumber;
- statistik dan insight dapat ditelusuri ke input, tidak mengubah data hilang menjadi nol, dan tidak mengklaim makna fisiologis tanpa validasi;
- uji dilakukan pada platform/perangkat dan provider yang diklaim didukung;
- dokumentasi konfigurasi, deployment, rollback, keterbatasan, dan cara mengulang tes diperbarui;
- Review menunjukkan bukti nyata. Mock/fixture boleh untuk tes, tetapi tidak membuktikan integrasi produksi.

## 5. Product Backlog Terurut

Urutan berikut menempatkan pencatatan dan peninjauan latihan cyclist sebelum ekstensi. Perekaman lokal/offline tidak boleh menunggu OAuth, Supabase, AI, atau provider peta. Identity/cloud tetap wajib untuk kapabilitas online yang memerlukannya. PBI dapat dipecah saat refinement; P0/P1/P2 menunjukkan prioritas relatif, bukan komitmen tanggal.

### P0 — Siklus inti cyclist: siapkan, rekam, tinjau

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-21 | **Ride capture saat layar mati dan pemulihan sesi** | Rekaman memakai mekanisme background resmi Android/iOS, izin/indikator sistem yang diperlukan, persistensi berkala dan strategi baterai yang diuji. Setelah app/process dihentikan, sesi kembali sebagai dijeda untuk konfirmasi, tanpa durasi/sampel fiktif. Batas OS/izin dijelaskan; perekaman offline tetap jalan. Validasi pada perangkat sasaran termasuk layar mati, panggilan/interupsi, low battery, force-stop, dan revokasi izin. |
| SP-22 | **Aktivitas, riwayat dan detail ride** | Cyclist dapat memberi judul/jenis sesi (latihan, balap, indoor sesuai dukungan), membuka riwayat dan detail, melihat summary/map/quality/sync, dan membedakan hasil rekaman dari import. Perubahan metadata tidak mengubah sampel; import/retry tidak menggandakan aktivitas. |
| SP-23 | **Progress dashboard yang dapat dijelaskan** | Hitung frekuensi sesi, jarak, durasi aktif, dan elevasi bila cukup data untuk periode yang dipilih; bandingkan rentang sepadan dan tautkan setiap angka/grafik ke aktivitas sumber. Unit dan zona waktu konsisten; data parsial/ganda tidak disamarkan menjadi angka pasti atau klaim fitness. |
| SP-24 | **Target aktivitas personal (opsional)** | Cyclist dapat membuat target sederhana pilihan sendiri (jumlah sesi, jarak, atau durasi dalam periode); progres memakai sesi selesai yang unik, target dapat diubah/dihapus, dan tidak dipresentasikan sebagai resep latihan profesional. |
| SP-25 | **Workout interval buatan cyclist** | Cyclist membuat dan menyimpan rangkaian interval waktu/jarak serta pemulihan secara lokal, memilihnya sebelum ride, dan menerima cue audio/haptic/visual yang dapat dimatikan. Pause/finish/recovery menyelaraskan workout dengan sesi tanpa melanjutkan diam-diam; jarak tidak maju tanpa sumber valid; cue gagal tidak menghentikan rekaman. Tidak memberi resep intensitas atau klaim medis. |
| SP-01 | **Autentikasi Google dan lifecycle session** | Login/registrasi Google lewat alur OAuth resmi yang sesuai untuk mobile (state/PKCE/validasi callback), HTTPS/TLS, dan validasi token di sisi server; token tidak ditulis ke log; session dapat dipulihkan sesuai aturan, diperbarui, dan dicabut saat logout; error provider, cancel, jaringan putus, dan akun tidak terkonfigurasi memiliki pesan/pemulihan. Tidak meminta password Google. |
| SP-02 | **Biometric local unlock** | Setelah login cloud berhasil, pengguna dapat mengaktifkan biometrik di perangkat yang mendukungnya. Validasi biometrik membuka akses lokal, tidak membuat session cloud baru; penolakan, sensor tidak tersedia, lockout, dan fallback ditangani. Pengguna dapat menonaktifkannya. |
| SP-03 | **Penyimpanan lokal dan Supabase** | Data inti punya model lokal dan remote yang konsisten; migrasi Drift dan schema Supabase terdokumentasi; RLS membatasi data per pengguna; keputusan enkripsi local at-rest diuji; uji restart/offline/reinstall/penghapusan membuktikan perilaku data. |
| SP-04 | **Sinkronisasi offline-first** | Outbox memakai ID stabil, retry idempotent, acknowledgment server, kebijakan konflik dan status terlihat. Force-stop/restart atau logout tidak menghilangkan item pending; item tidak pernah ditandai tersinkron sebelum server mengonfirmasi. |
| SP-05 | **API dan service boundary** | Kontrak endpoint/service, autentikasi/otorisasi, validasi input, timeout, error mapping, rate limit untuk endpoint publik/mahal, versioning, dan observability tanpa payload sensitif tersedia. Environment dev/staging/prod terpisah; secret server tidak masuk bundle aplikasi. |
| SP-06 | **Pencarian dan pemilihan perjalanan** | Pengguna dapat mencari tempat/rute, memfilter atau mengurutkan hasil yang disepakati, membuka detail dan memilih/menyimpan item. Sumber, waktu pembaruan, loading/empty/error, izin lokasi, offline, dan timeout provider terlihat. Hasil palsu tidak ditampilkan saat API gagal. |
| SP-07 | **Persiapan ride, LBS dan lifecycle sesi** | Peta Jelajah/Beranda dapat dibuka tanpa GPX; izin lokasi diminta hanya saat relevan. Pengguna melihat posisi atau memilih GPX, lalu start/pause/resume/stop sesi. Tampilkan basemap OSM online beratribusi, kualitas fix, status recording/offline dan geometri lokal saat tile gagal. Stop membersihkan subscription/service; ride tersimpan lokal dan dapat dipulihkan. Turn-by-turn hanya dengan provider berlisensi/aktif. |
| SP-08 | **Siklus data akun** | Pengguna dapat melihat status sync, logout dengan pencabutan/clear session lokal yang tepat, mengekspor data, meminta penghapusan akun, dan memahami apa yang tetap tersimpan. Kebijakan local-vs-cloud dan retensi dijelaskan; kegagalan penghapusan tidak dilaporkan sukses. |

### P1 — Pendamping perjalanan dan fitur perangkat

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-09 | **Sensor gerak: accelerometer dan gyroscope** | Minta akses hanya saat fitur terkait dipakai. Uji bahwa kedua sensor terdeteksi dan menghasilkan nilai/waktu dengan sampling serta konsumsi baterai yang disepakati. Sensor yang hilang/ditolak tidak merusak sesi; data mentah tidak dikirim tanpa kebutuhan/consent. UI menjelaskan kegunaan dan status sensor. |
| SP-10 | **AI non-generatif untuk aktivitas/progres** | Memenuhi FR-05 dan FR-12 dengan use case, input, dataset, dan evaluasi terpisah: pola faktual pada ride/rute serta tren kategori jawaban tantangan strategi. Pipeline terpisah dari LLM; sumber, versi model, metrik/ambang, confidence dan fallback terdokumentasi. Tidak menyimpulkan fitness medis, kesiapan lomba, atau insiden; bila bukti belum cukup, tampilkan sebagai eksperimen/tidak tersedia. |
| SP-11 | **Asisten LLM untuk cyclist** | Memenuhi FR-32: LLM menjawab pertanyaan tentang rute/aktivitas dengan konteks eksplisit yang dipilih pengguna, bukan AI analitik. Consent mendahului pengiriman; sumber data provider tidak dikarang; secret, kuota, moderasi, timeout, penghapusan riwayat dan kegagalan ditangani. Jawaban bukan instruksi keselamatan/diagnosis. |
| SP-12 | **Konversi mata uang** | Pengguna memilih mata uang sumber/tujuan, nominal, dan melihat nilai serta waktu/sumber kurs. Mode offline memakai kurs tersimpan yang diberi label tanggal, bukan kurs live. Nilai invalid, kurs tidak tersedia, pembulatan, dan kegagalan API ditangani. |
| SP-13 | **Konversi waktu dunia** | Cari dan pilih lokasi/zona waktu dari daftar zona waktu dunia berbasis IANA; konversi waktu/tanggal antar zona menampilkan nama lokasi, offset, dan tanggal lokal dengan dukungan daylight-saving serta perubahan tanggal. Tes mencakup zona berbeda dan transisi DST; jangan hanya menggeser jam dengan offset statis. |
| SP-14 | **Bottom navigation dan profil** | Lima tab Beranda/Jelajah/Rekam/Tools/Profil membuka alur utama dan mempertahankan state yang wajar. Profil menyediakan preferensi, izin, privasi, **Saran dan Kesan — Mata Kuliah Pemrograman Aplikasi Mobile**, dan **Logout**. Form saran/feedback memvalidasi input, menampilkan acknowledgment nyata, dan menyatakan jika pengiriman offline/pending/gagal. |
| SP-15 | **Push notification berbasis mobile** | Pengguna memilih opt-in dan kategori; izin OS dapat ditolak/dicabut; token perangkat diikat ke akun secara aman dan dapat dihapus saat logout. Delivery/deep link/token kedaluwarsa/offline/duplikasi diuji. Push bukan kanal jaminan SOS dan payload lock-screen tidak menyertakan koordinat atau data sensitif. |
| SP-16 | **Tantangan strategi rute/balap** | Ganti tes reaksi visual dengan skenario strategi rute/balap yang dimainkan saat berhenti; pilihan memberi trade-off/penjelasan dan skor disimpan lokal. Blokir game saat sesi merekam atau dijeda; tidak memberi instruksi real-time, klaim medis, atau saran keselamatan tervalidasi. |
| SP-26 | **Sensor sepeda eksternal** | Setelah protokol/perangkat sasaran diputuskan, pasangkan sensor BLE yang didukung (misalnya HR/cadence/speed/power) melalui profil standar relevan. Sampel menyimpan sumber, unit, waktu, dan kualitas; izin, disconnect/reconnect, stale data, range, duplikasi, dan consent sinkronisasi diuji. Sensor hilang tidak menghentikan rekaman lokal dan nilai tidak dibuat-buat. |
| SP-27 | **Integrasi wearable Garmin Health** | Alur pairing/consent, import metrik yang benar-benar disediakan API, deduplikasi dan pencabutan akses. PBI tetap blocked sampai approval partner dan credentials resmi tersedia; sebelum itu UI menyatakan belum tersedia dan tidak meminta kredensial palsu. Data diberi label sumber/waktu dan tidak disebut real-time tanpa dukungan provider. |

### P2 — Nilai tambahan setelah fondasi lulus

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-17 | **Proof perjalanan blockchain sederhana** | Target staging Polygon Amoy melalui relayer server-side. Dengan consent eksplisit, buat hash ringkasan terpilih (bukan lokasi mentah/identitas); simpan pending/confirmed/failed dan transaction reference. Uji kontrak, retry idempoten, dan verifikasi hash di Amoy. Produksi/mainnet menunggu uji biaya serta keputusan terpisah; tidak ada klaim immutable sebelum verifikasi. |
| SP-18 | **Pengingat hidrasi dan peringatan perubahan ride** | Pengguna dapat memilih pengingat hidrasi lokal dan peringatan rute/cuaca hanya jika sumber data benar tersedia. Frekuensi, quiet hours, volume/audio, timezone, offline, dismiss, serta kondisi ride diuji; data stale diberi label dan notifikasi tidak mengklaim incident/SOS delivery. |
| SP-19 | **Peningkatan peta dan layanan perjalanan** | Tambahkan POI/rute/fitur provider (misalnya geocoding, elevasi, atau reroute) hanya jika lisensi, biaya, kuota, atribusi, kualitas, dan cache/offline policy disetujui dan diuji. Evaluasi provider tile khusus sebelum trafik produksi; layanan tile publik tidak dianggap komitmen produksi. GPX offline tetap tersedia bila provider gagal. |
| SP-20 | **Leaderboard sesi mingguan opt-in** | Supabase/Postgres menyajikan dua peringkat Senin–Minggu UTC: durasi aktif terlama dan jarak terjauh dari sesi yang selesai. Fungsi PostgreSQL `SECURITY DEFINER` memvalidasi auth, consent, dan mengambil nilai hanya dari ringkasan milik pengguna yang telah tersinkron. Pengguna memilih opt-in dan alias publik. Hanya alias dan nilai kategori minggu berjalan yang dipublikasikan—tanpa email, lokasi, kontak, atau telemetri mentah. Tandai data sebagai laporan pengguna yang belum diverifikasi; uji RLS, opt-out/penghapusan, dan submission duplikat. |

### Keputusan provider yang disepakati

- **SOS:** pertahankan telepon/WhatsApp manual; aplikasi tidak mengklaim pesan terkirim. Deteksi insiden otomatis tetap nonaktif sampai model sensor divalidasi.
- **Proof blockchain:** Polygon Amoy untuk staging melalui relayer server-side; jaringan produksi dan batas biaya belum diputuskan.
- **Leaderboard:** Supabase/Postgres, fungsi RPC server-side, opt-in, alias publik, dan metrik sesi bersepeda mingguan (durasi serta jarak; minggu UTC).
- **Wearable:** adapter langsung Garmin Health API, tetapi tidak diaktifkan sebelum approval partner dan credentials resmi tersedia.
- **Sensor sepeda eksternal:** tetapkan perangkat/OS sasaran dan profil BLE yang diuji sebelum menjanjikan dukungan; sensor optional dan tidak boleh menjadi dependensi rekaman GPS.

## 6. Rencana Sprint Usulan

Sprint adalah wadah perencanaan, bukan komitmen tanggal. Durasi tim ditetapkan tim; PO memilih scope setelah kapasitas dan blocker diverifikasi.

### Sprint A — Discovery, arsitektur dan risiko

**Sprint Goal:** menyepakati pengalaman Senapath, platform sasaran, batas privasi/keselamatan, provider/API, dan kontrak data sebelum memperluas implementasi.

- Petakan layar/alur yang sudah ada dan bukti baseline; tandai implementasi lokal vs integrasi terdeploy.
- Putuskan OAuth Google/Supabase, auth callback, session lifecycle, model data, RLS, local encryption decision, serta skenario logout/penghapusan.
- Evaluasi provider tile skala produksi dan search, kurs, LLM, push, dan blockchain: lisensi, biaya, kuota, wilayah, data yang keluar, fallback. Basemap GPX MVP menggunakan tile OpenStreetMap online.
- Definisikan persona cyclist latihan/balap, data minimal tiap ride, statistik progres yang dipercaya, matrix perangkat/OS, lifecycle background, sampling/baterai, evaluasi AI, dan data yang boleh menjadi konteks LLM.
- Hasil Review: keputusan/risiko tercatat, acceptance criteria disetujui, backlog dipecah, dan item blocked diberi pemilik.

### Sprint B — Ride capture lokal yang tidak kehilangan data

**Sprint Goal:** cyclist dapat menyiapkan dan merekam sesi lokal dari start sampai finish tanpa akun cloud atau koneksi.

- Bangun lifecycle dan schema sesi/telemetri lokal (SP-03, SP-07) dengan ID stabil, unit kanonis, status serta kualitas sumber.
- Pastikan start/pause/resume/finish, app restart/recovery, export, dan summary dasar konsisten; recovery setelah proses mati menjadi paused, bukan rekaman yang pura-pura berjalan.
- Hasil Review: walkthrough ride offline; hasil summary cocok dengan sampel sumber; tidak ada klaim cloud sync.

### Sprint C — Background, peta dan sensor di perangkat sasaran

**Sprint Goal:** ride capture tetap andal saat layar mati dan cyclist dapat melihat rute/lokasi tanpa menyembunyikan keterbatasan platform.

- Implementasikan SP-21 dengan foreground/background mode sesuai Android/iOS, persistensi periodik, recovery, indikator OS, dan uji baterai.
- Sediakan peta eksplorasi dan rute GPX yang dapat dilihat kembali; integrasikan SP-07/SP-06 sesuai provider yang lolos evaluasi.
- Integrasikan SP-09 hanya untuk sumber sensor yang tersedia/diizinkan; uji GPS lemah, layar mati, panggilan, force-stop, revokasi izin dan penghentian stream.
- Hasil Review: demonstrasi lapangan terbatas pada perangkat sasaran; catat kondisi ketika OS menghentikan rekaman dan cara pemulihannya.

### Sprint D — Riwayat, summary dan progres

**Sprint Goal:** cyclist dapat menemukan sesi selesai dan memahami progres dari angka yang bisa ditelusuri ke aktivitas sumber.

- Bangun metadata aktivitas, riwayat, detail dan summary (SP-22); validasi import tidak membuat aktivitas ganda.
- Bangun statistik periodik dan target pilihan pengguna (SP-23/SP-24); cocokkan agregat secara otomatis dengan fixtures beragam dan source activities.
- Bangun builder workout interval lokal (SP-25) sebagai alat yang dikendalikan cyclist; uji timer/cue tetap tersinkron dengan lifecycle sesi dan tidak mengganggu ride capture.
- Uji data kosong/parsial, unit, timezone, duplikasi import, offline dan volume besar; insight tidak mengubah missing data menjadi nol.
- Hasil Review: cyclist dapat menelusuri setiap agregat ke sesi pembentuk; tidak ada klaim fitness/medis tanpa validasi.

### Sprint E — Akun, sync dan API

**Sprint Goal:** akun/cloud memperluas akses tanpa mengorbankan data lokal dan status server yang jujur.

- Kerjakan SP-01/SP-02 dengan OAuth Google dan local unlock sebagai alur yang berbeda; uji cancel, callback, revoke, logout dan offline.
- Implementasikan kontrak API, Supabase migrations/RLS, status service, dan outbox/retry idempotent (SP-03/SP-04/SP-05/SP-08).
- Putuskan secara eksplisit apakah sync ringkasan atau raw telemetry; dokumentasikan data, consent, batas ukuran, konflik, retensi, dan penghapusan.
- Hasil Review: tes multi-account/RLS pada staging; sesi lokal tetap tersedia saat logout, backend gagal atau jaringan mati.

### Sprint F — Companion extensions: tools dan kecerdasan terpisah

**Sprint Goal:** fitur pendukung cyclist menambah nilai tanpa berpura-pura menjadi data ride atau rekomendasi profesional.

- Bangun konversi mata uang/waktu (SP-12/SP-13) sebagai alat logistik sekunder.
- Evaluasi AI non-generatif dari aktivitas hanya setelah data histori berkualitas dan dataset/metrik tersedia (SP-10); LLM tetap pipeline, consent, label, dan biaya terpisah (SP-11).
- Hasil Review: angka statistik tetap berfungsi tanpa AI/LLM; AI menyebut sumber/ketidakpastian; LLM tidak mengarang kondisi provider.

### Sprint G — Ekstensi pilihan cyclist

**Sprint Goal:** alur navigasi lengkap dan fitur tambahan dapat dikontrol pengguna dengan aman.

- Selesaikan profil/feedback, notifikasi opt-in dan pengingat ride (SP-14/SP-15/SP-18).
- Integrasikan mini-game strategi yang aman saat berhenti (SP-16), leaderboard bersepeda opt-in (SP-20), sensor eksternal (SP-26) setelah protokol/perangkat disepakati, wearable (SP-27) hanya setelah approval, dan proof Amoy (SP-17) sesuai gate masing-masing.
- Hasil Review: kegagalan/opt-out ekstensi tidak memengaruhi rekaman, summary, atau histori cyclist; uji izin ditolak, data sensitif dan biaya.

### Sprint H — Hardening dan release candidate

**Sprint Goal:** hanya fitur yang lolos bukti keamanan, integrasi, perangkat, dan operasi masuk build terbatas.

- Kerjakan proof perjalanan (SP-17) hanya jika ledger/biaya/threat model/consent disetujui; jika belum, tetap blocked tanpa mengganti dengan status palsu.
- Jalankan SP-08 untuk ekspor/penghapusan dan verifikasi retensi lokal/cloud.
- Uji full flow, migrasi upgrade, perangkat/OS target, offline/online, accessibility, analisis dependensi, konfigurasi release, rollback, monitoring, backup/restore, dan support runbook.
- PO menerima daftar fitur tersedia, belum tersedia, risiko residual, platform/provider teruji, serta kriteria release. Defect blocker/high harus ditutup atau dikecualikan secara eksplisit dengan alasan dan mitigasi.

## 7. Release Gates

Jangan menyebut produk siap produksi sampai semua gate yang masuk scope rilis memiliki bukti:

- **Build/perangkat:** build distribusi bertanda tangan; instalasi baru dan upgrade; uji OS/perangkat minimum serta lifecycle sensor/lokasi.
- **Identitas/data:** Google OAuth dan session diuji dengan project nyata; RLS diuji lintas akun; logout, revocation, ekspor, penghapusan lokal/cloud, backup dan restore diverifikasi.
- **Keamanan/privasi:** TLS, penyimpanan token, local at-rest encryption bila diklaim, secrets, izin, consent, retensi, logs tanpa data sensitif, serta dependency advisories ditinjau.
- **API/provider:** endpoint nyata, validasi/authorization, rate/kuota, timeout, migrasi, deployment, monitoring, dan fallback diuji; key server tidak ada di app bundle.
- **Offline:** data lokal bertahan restart/force-stop; retry idempotent; status local/pending/confirmed akurat; cache tidak merusak sesi.
- **LBS/sensor:** izin dicabut/ditolak, GPS lemah, sensor absen, background, baterai, stop recording, dan recovery diuji pada device.
- **AI/LLM:** evaluasi AI sesuai metrik yang disetujui; consent dan data flow LLM terverifikasi; output diberi label; kegagalan tidak mengarang hasil.
- **Notifikasi/game/blockchain:** push opt-in dan penghapusan token lulus; game tidak mendorong interaksi saat bergerak; proof hash dapat diverifikasi dan tidak mengekspos data pribadi.
- **Kualitas/operasi:** automated tests, static analysis, integration/device smoke, accessibility dasar, observability, incident owner, support contact, batas biaya, release notes, dan rollback tersedia.

Jika gate belum lulus, batasi rilis ke internal/tester dan nyatakan fitur sebagai belum tersedia atau eksperimental.

## 8. Transparansi Status, Risiko dan Pengukuran

Gunakan status konsisten: **belum dikonfigurasi**, **offline**, **memuat**, **tersedia**, **tersimpan lokal**, **menunggu sinkronisasi**, **terkonfirmasi**, dan **gagal**. Tampilkan status sesuai bukti: `hash dibuat` bukan `proof terverifikasi`; `login lokal terbuka` bukan `session cloud valid`; `permintaan push dibuat` bukan `notifikasi diterima`; track GPX bukan navigasi jalan.

Pada setiap Review, catat PBI diterima/ditolak, hasil tes, perangkat dan environment yang diuji, provider/versinya, blocker, risiko residual, keputusan PO, dan langkah tindak lanjut. Metrik awal yang disepakati tim dapat meliputi keberhasilan login/sync, kegagalan crash, usia data kurs, akurasi klasifikasi AI, respons/timeout LLM, konsumsi baterai perekaman, dan status delivery push. Metrik tidak boleh mengumpulkan lokasi atau konten percakapan tanpa kebutuhan dan consent. Velocity untuk forecast tim, bukan target individu.
