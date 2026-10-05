# Scrum Guide dan Product Backlog — Senapath

## 1. Visi Produk

**Senapath adalah pendamping perjalanan dan bersepeda yang membantu pengguna merencanakan perjalanan, merekam aktivitas secara aman, dan memahami informasi perjalanan meskipun koneksi tidak selalu tersedia.**

Peta dan Location-Based Services (LBS) menjadi konteks utama. Akun dan sinkronisasi menjaga data antarperangkat; sensor membantu memahami aktivitas; pencarian, konversi mata uang/waktu, serta rekomendasi mendukung perencanaan; AI dan LLM memiliki tanggung jawab berbeda; mini-game menjadi latihan singkat terkait aktivitas; notifikasi bersifat opt-in; dan blockchain hanya menyimpan bukti perjalanan minimal yang dipilih pengguna. Semua fitur harus tetap menjelaskan asal, status, izin, dan keterbatasan datanya.

**Product Goal:** menghasilkan aplikasi mobile yang memungkinkan pengguna masuk dengan Google secara aman, mengunci akses lokal dengan biometrik, merencanakan dan merekam perjalanan berbasis lokasi, menyimpan data secara lokal dan menyinkronkannya ke Supabase, serta menggunakan alat dan fitur pendamping perjalanan tanpa mengaburkan status offline/online atau mengorbankan privasi.

Target platform, provider kurs/cuaca, biaya, serta lingkungan deployment harus diputuskan dan dicatat sebelum integrasi provider. Rencana sprint di bawah adalah urutan usulan, bukan estimasi tanggal atau janji rilis. Peta GPX menggunakan OpenStreetMap online untuk basemap; geocoding/routing dan provider tile skala produksi tetap memerlukan keputusan tersendiri.

## 2. Konsep dan Batasan Produk

### Pengalaman inti

1. Pengguna membuat akun atau masuk dengan Google; setelah autentikasi, biometrik dapat dipakai untuk membuka akses lokal pada perangkat.
2. Pengguna mencari dan memilih tempat/rute, melihat detail dan kondisi koneksi, lalu menyimpan rencana agar informasi penting tetap tersedia offline.
3. Saat perjalanan, pengguna merekam sesi lokasi dan sensor yang diizinkan. Aplikasi menampilkan status izin, akurasi, perekaman, dan sinkronisasi dengan jelas.
4. Pengguna membuka **Tools** untuk konversi mata uang dan waktu dunia, serta **Profil** untuk pengaturan, saran dan kesan mata kuliah Pemrograman Aplikasi Mobile, dan logout.
5. AI non-generatif menghasilkan klasifikasi atau rekomendasi terukur; LLM menangani percakapan dan ringkasan kontekstual. Hasil keduanya diberi label dan tidak dipakai sebagai jaminan keselamatan.
6. Pengguna dapat memilih notifikasi yang diinginkan, mencoba mini-game latihan yang aman, serta secara terpisah memilih membuat bukti perjalanan berbasis hash.

### Navigasi utama

Bottom navigation yang diusulkan:

| Tab | Isi utama |
| --- | --- |
| **Beranda** | Ringkasan perjalanan, sesi terakhir, status offline/sinkronisasi, pintasan. |
| **Jelajah** | Pencarian tempat/rute, hasil yang dapat dipilih, detail, simpan rencana. |
| **Rekam** | Mulai/jeda/lanjutkan/akhiri sesi, peta/LBS, status sensor dan lokasi. |
| **Tools** | Konversi mata uang, konversi waktu dunia, latihan/mini-game, asisten. |
| **Profil** | Akun, preferensi, izin, privasi, **Saran dan Kesan — Mata Kuliah Pemrograman Aplikasi Mobile**, penghapusan data, dan **Logout**. |

Nama dan jumlah tab dapat diselaraskan dengan pola UI aplikasi yang sudah ada saat refinement, tetapi seluruh fungsi dan jalan kembali harus dapat ditemukan. Logout bukan pengganti penghapusan akun atau data.

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

Dokumen sebelumnya mencatat implementasi lokal untuk unlock perangkat, sesi Drift, impor/ekspor GPX/JSON, latihan reaksi, konversi logistik, chat AI, feedback, dan penyimpanan offline. Ada UI/gateway auth email/password Supabase. Catatan tersebut bukan bukti bahwa integrasi provider berjalan di semua environment.

Status yang perlu diverifikasi lagi sebelum planning:

- Gateway dan callback Google OAuth melalui Supabase tersedia di aplikasi; provider credentials/redirect allow-list pada dashboard dan pengujian live di project/perangkat nyata masih harus diverifikasi sebelum dinyatakan siap.
- Login biometrik yang sudah ada merupakan local unlock; bukan Google login atau autentikasi backend.
- Sinkronisasi ringkasan sesi selesai ke Supabase kini memiliki consent eksplisit, pemeriksaan akun/config, upsert idempoten, status lokal, dan migrasi RLS; penerapan migrasi serta pengujian RLS/deployment pada project nyata belum diverifikasi. Koordinat dan telemetri mentah tidak ikut dikirim. Konflik offline dan sync otomatis/outbox umum belum tersedia.
- Basemap GPX menggunakan tile OpenStreetMap online dengan atribusi; track lokal tetap terlihat offline, tetapi tile tidak tersedia offline. Geocoding, pencarian rute online, turn-by-turn, dan provider tile produksi belum tersedia/diputuskan.
- Konversi waktu kini memakai database zona waktu IANA lokal yang dapat dicari, termasuk penanganan waktu DST hilang/berulang; konversi kurs tetap hanya referensi harian/manual, bukan kurs live.
- Chat AI atau package/model lokal bukan bukti deployment LLM maupun AI ML yang tervalidasi.
- Push notification, integrasi sensor produksi, mini-game aman, dan proof blockchain belum dianggap tersedia sampai diuji pada perangkat dan layanan yang ditargetkan.
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
- uji dilakukan pada platform/perangkat dan provider yang diklaim didukung;
- dokumentasi konfigurasi, deployment, rollback, keterbatasan, dan cara mengulang tes diperbarui;
- Review menunjukkan bukti nyata. Mock/fixture boleh untuk tes, tetapi tidak membuktikan integrasi produksi.

## 5. Product Backlog Terurut

Urutan berikut mengutamakan fondasi identitas/data dan risiko perjalanan sebelum fitur tambahan. PBI dapat dipecah saat refinement. P0/P1/P2 menunjukkan prioritas relatif, bukan komitmen rilis.

### P0 — Fondasi aman dan perjalanan yang dapat diandalkan

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-01 | **Autentikasi Google dan lifecycle session** | Login/registrasi Google lewat alur OAuth resmi yang sesuai untuk mobile (state/PKCE/validasi callback), HTTPS/TLS, dan validasi token di sisi server; token tidak ditulis ke log; session dapat dipulihkan sesuai aturan, diperbarui, dan dicabut saat logout; error provider, cancel, jaringan putus, dan akun tidak terkonfigurasi memiliki pesan/pemulihan. Tidak meminta password Google. |
| SP-02 | **Biometric local unlock** | Setelah login cloud berhasil, pengguna dapat mengaktifkan biometrik di perangkat yang mendukungnya. Validasi biometrik membuka akses lokal, tidak membuat session cloud baru; penolakan, sensor tidak tersedia, lockout, dan fallback ditangani. Pengguna dapat menonaktifkannya. |
| SP-03 | **Penyimpanan lokal dan Supabase** | Data inti punya model lokal dan remote yang konsisten; migrasi Drift dan schema Supabase terdokumentasi; RLS membatasi data per pengguna; keputusan enkripsi local at-rest diuji; uji restart/offline/reinstall/penghapusan membuktikan perilaku data. |
| SP-04 | **Sinkronisasi offline-first** | Outbox memakai ID stabil, retry idempotent, acknowledgment server, kebijakan konflik dan status terlihat. Force-stop/restart atau logout tidak menghilangkan item pending; item tidak pernah ditandai tersinkron sebelum server mengonfirmasi. |
| SP-05 | **API dan service boundary** | Kontrak endpoint/service, autentikasi/otorisasi, validasi input, timeout, error mapping, rate limit untuk endpoint publik/mahal, versioning, dan observability tanpa payload sensitif tersedia. Environment dev/staging/prod terpisah; secret server tidak masuk bundle aplikasi. |
| SP-06 | **Pencarian dan pemilihan perjalanan** | Pengguna dapat mencari tempat/rute, memfilter atau mengurutkan hasil yang disepakati, membuka detail dan memilih/menyimpan item. Sumber, waktu pembaruan, loading/empty/error, izin lokasi, offline, dan timeout provider terlihat. Hasil palsu tidak ditampilkan saat API gagal. |
| SP-07 | **LBS, peta dan sesi perjalanan** | Pengguna dapat melihat lokasi dengan izin yang sesuai, memilih rencana/GPX, lalu start/pause/resume/stop sesi. Tampilkan tile basemap OpenStreetMap online beratribusi, kualitas/akurasi fix, status recording, progres dan status offline. Track tetap terlihat saat tile gagal/offline. Stop membersihkan subscription/service; data sesi tersimpan lokal dan dapat dipulihkan. Turn-by-turn hanya bila provider berlisensi dan aktif. |
| SP-08 | **Siklus data akun** | Pengguna dapat melihat status sync, logout dengan pencabutan/clear session lokal yang tepat, mengekspor data, meminta penghapusan akun, dan memahami apa yang tetap tersimpan. Kebijakan local-vs-cloud dan retensi dijelaskan; kegagalan penghapusan tidak dilaporkan sukses. |

### P1 — Pendamping perjalanan dan fitur perangkat

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-09 | **Sensor gerak: accelerometer dan gyroscope** | Minta akses hanya saat fitur terkait dipakai. Uji bahwa kedua sensor terdeteksi dan menghasilkan nilai/waktu dengan sampling serta konsumsi baterai yang disepakati. Sensor yang hilang/ditolak tidak merusak sesi; data mentah tidak dikirim tanpa kebutuhan/consent. UI menjelaskan kegunaan dan status sensor. |
| SP-10 | **AI non-generatif untuk aktivitas/rekomendasi** | Pipeline AI yang terpisah dari LLM mengklasifikasikan pola gerak atau memberi rekomendasi perjalanan berdasarkan fitur/data yang disetujui. Sumber input dan versi model diketahui; hasil diuji terhadap data representatif dengan metrik/ambang penerimaan yang disepakati PO; confidence rendah ditandai tidak pasti. Bukan deteksi kecelakaan atau saran keselamatan yang dijamin. |
| SP-11 | **Asisten LLM perjalanan** | Percakapan LLM terpisah dari AI klasifikasi; menjawab pertanyaan perjalanan menggunakan konteks yang diizinkan (misalnya rencana/ringkasan yang dipilih), menyebut batas pengetahuan, dan tidak mengarang status API. Persetujuan sebelum mengirim data kontekstual; server menyimpan provider secret; batas ukuran, timeout, rate/quota, moderasi, penghapusan riwayat, dan respons gagal diuji. |
| SP-12 | **Konversi mata uang** | Pengguna memilih mata uang sumber/tujuan, nominal, dan melihat nilai serta waktu/sumber kurs. Mode offline memakai kurs tersimpan yang diberi label tanggal, bukan kurs live. Nilai invalid, kurs tidak tersedia, pembulatan, dan kegagalan API ditangani. |
| SP-13 | **Konversi waktu dunia** | Cari dan pilih lokasi/zona waktu dari daftar zona waktu dunia berbasis IANA; konversi waktu/tanggal antar zona menampilkan nama lokasi, offset, dan tanggal lokal dengan dukungan daylight-saving serta perubahan tanggal. Tes mencakup zona berbeda dan transisi DST; jangan hanya menggeser jam dengan offset statis. |
| SP-14 | **Bottom navigation dan profil** | Lima tab Beranda/Jelajah/Rekam/Tools/Profil membuka alur utama dan mempertahankan state yang wajar. Profil menyediakan preferensi, izin, privasi, **Saran dan Kesan — Mata Kuliah Pemrograman Aplikasi Mobile**, dan **Logout**. Form saran/feedback memvalidasi input, menampilkan acknowledgment nyata, dan menyatakan jika pengiriman offline/pending/gagal. |
| SP-15 | **Push notification berbasis mobile** | Pengguna memilih opt-in dan kategori; izin OS dapat ditolak/dicabut; token perangkat diikat ke akun secara aman dan dapat dihapus saat logout. Uji delivery, deep link, token kedaluwarsa, offline, duplikasi, dan pengaturan. Payload lock-screen tidak menyertakan koordinat atau data sensitif. |
| SP-16 | **Mini-game latihan perjalanan** | Sedikitnya satu mini-game singkat terkait kesiapan/perhatian atau respons perjalanan; skor lokal dan aturan dijelaskan. Tidak memberikan klaim medis/kemampuan berkendara; menghentikan atau membatasi permainan saat sesi recording aktif dan mencegah ajakan interaksi saat bergerak. |

### P2 — Nilai tambahan setelah fondasi lulus

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-17 | **Proof perjalanan blockchain sederhana** | Dengan consent eksplisit, buat hash dari ringkasan terpilih (bukan lokasi mentah/identitas) dan simpan proof melalui mekanisme/ledger yang dipilih. Tampilkan pending/confirmed/failed dan referensi verifikasi; perubahan data membatalkan kecocokan hash. Biaya, jaringan, retensi, dan threat model disetujui. Tidak ada klaim decentralized/immutable sebelum diuji. |
| SP-18 | **Notifikasi dan rekomendasi kontekstual** | Setelah opt-in, pengguna bisa memilih pengingat perjalanan atau pembaruan rencana. Frekuensi, timezone, duplikasi, quiet hours, kondisi jaringan, dan disable diuji; rekomendasi AI tidak otomatis memulai perjalanan atau tindakan eksternal. |
| SP-19 | **Peningkatan peta dan layanan perjalanan** | Tambahkan POI/rute/fitur provider (misalnya geocoding, elevasi, atau reroute) hanya jika lisensi, biaya, kuota, atribusi, kualitas, dan cache/offline policy disetujui dan diuji. Evaluasi provider tile khusus sebelum trafik produksi; layanan tile publik tidak dianggap komitmen produksi. GPX offline tetap tersedia bila provider gagal. |

## 6. Rencana Sprint Usulan

Sprint adalah wadah perencanaan, bukan komitmen tanggal. Durasi tim ditetapkan tim; PO memilih scope setelah kapasitas dan blocker diverifikasi.

### Sprint A — Discovery, arsitektur dan risiko

**Sprint Goal:** menyepakati pengalaman Senapath, platform sasaran, batas privasi/keselamatan, provider/API, dan kontrak data sebelum memperluas implementasi.

- Petakan layar/alur yang sudah ada dan bukti baseline; tandai implementasi lokal vs integrasi terdeploy.
- Putuskan OAuth Google/Supabase, auth callback, session lifecycle, model data, RLS, local encryption decision, serta skenario logout/penghapusan.
- Evaluasi provider tile skala produksi dan search, kurs, LLM, push, dan blockchain: lisensi, biaya, kuota, wilayah, data yang keluar, fallback. Basemap GPX MVP menggunakan tile OpenStreetMap online.
- Definisikan event/data sensor minimum, izin runtime, target sampling/baterai, evaluasi AI non-generatif, dan data yang boleh menjadi konteks LLM.
- Hasil Review: keputusan/risiko tercatat, acceptance criteria disetujui, backlog dipecah, dan item blocked diberi pemilik.

### Sprint B — Identitas, session dan fondasi data

**Sprint Goal:** pengguna dapat masuk dengan Google secara aman dan mempertahankan data inti lokal tanpa menganggapnya sudah sinkron.

- Kerjakan SP-01 sampai slice autentikasi yang siap; uji callback, cancel, refresh, expired/revoked session, dan kegagalan offline.
- Uji SP-02 sebagai local unlock terpisah dengan fallback perangkat.
- Bangun migrasi lokal dan Supabase/RLS untuk model inti yang disepakati; jangan migrasikan data sensitif tanpa kebijakan.
- Hasil Review: demonstrasi pada device/emulator target dan staging; bukti token/log/session serta daftar gap.

### Sprint C — API, offline sync dan pencarian

**Sprint Goal:** pengguna dapat menemukan dan menyimpan rencana, serta membedakan data lokal dari data yang server konfirmasi.

- Implementasikan boundary service/API, environment, validasi dan status error (SP-05).
- Implementasikan sync outbox serta pemulihan dan retry idempotent (SP-04).
- Implementasikan search/select minimal pada Jelajah (SP-06), dengan provider dan batas penggunaannya disetujui.
- Hasil Review: uji online/offline, timeout, duplikasi retry, RLS lintas akun, restart, dan fallback provider.

### Sprint D — LBS, perekaman dan sensor

**Sprint Goal:** perjalanan dapat direncanakan dan direkam dengan status lokasi/sensor yang jujur dan alur aman.

- Integrasikan LBS/peta dan lifecycle sesi (SP-07); jaga dukungan track lokal ketika basemap online tidak tersedia.
- Integrasikan accelerometer dan gyroscope (SP-09) secara opt-in; uji permission, hardware tidak tersedia, lifecycle, sampling, dan baterai.
- Jalankan uji lapangan terbatas dalam kondisi aman; uji GPS lemah, background, app restart, dan penghentian stream.
- Hasil Review: demonstrasi perjalanan dan catatan platform/ketepatan serta batasan; tidak mengklaim turn-by-turn tanpa bukti provider.

### Sprint E — Tools, AI dan LLM terpisah

**Sprint Goal:** alat waktu/kurs dan fitur kecerdasan membantu perencanaan tanpa menyamakan model prediktif dengan chatbot generatif.

- Bangun konversi mata uang dan waktu dunia (SP-12, SP-13), termasuk freshness, offline, dan DST.
- Bangun baseline AI non-generatif beserta dataset uji/metrik (SP-10); bila bukti kualitas belum cukup, tandai eksperimen dan jangan tampilkan sebagai rekomendasi siap pengguna.
- Bangun LLM lewat service backend dengan consent dan batas data (SP-11); uji prompt/data leakage, timeout, quota, dan respons tanpa sumber.
- Hasil Review: fitur jelas terpisah di UI dan dokumentasi; hasil AI dievaluasi, interaksi LLM memperlihatkan batasannya.

### Sprint F — Profil, notifikasi dan mini-game

**Sprint Goal:** alur navigasi lengkap dan fitur tambahan dapat dikontrol pengguna dengan aman.

- Selesaikan bottom navigation dan profil termasuk saran/kesan mata kuliah dan logout (SP-14).
- Implementasikan push notification opt-in dan preferensi (SP-15); uji di perangkat/platform nyata.
- Implementasikan mini-game (SP-16) dengan pembatasan saat sesi aktif dan uji UX/accessibility.
- Hasil Review: walkthrough dari login ke logout; uji permission ditolak, push dimatikan, feedback gagal, dan game saat sesi berjalan.

### Sprint G — Proof, hardening dan release candidate

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
