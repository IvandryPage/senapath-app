# Scrum Guide dan Product Backlog — Senapath

## 1. Visi Produk

> **Tujuan besar:** Senapath adalah **"Strava untuk cyclist"** — rumah digital cyclist untuk merekam, menemukan/merencanakan rute, berlatih, dan terhubung dengan komunitas, dengan tumpukan gratis/OSS dan etika data yang kuat. Lihat [vision.md](vision.md) dan [tech-stack.md](tech-stack.md).

**Senapath adalah cycling companion untuk cyclist latihan dan balap: siapkan rute dan sesi, rekam perjalanan dengan andal, pahami progres dari data yang transparan, dan terhubung dengan cyclist lain.**

Siklus inti produk adalah **persiapan rute → ride capture → ride review/progress**, yang diperluas ke empat pilar visi: **Ride, Discover & Plan, Train, Connect**. Rekaman lokal, pemulihan sesi, peta/LBS, ringkasan yang benar, riwayat, statistik progres, segmen, dan interaksi sosial adalah nilai utama. Sinkronisasi cloud memperluas akses, tetapi tidak menjadi syarat untuk merekam atau melihat data lokal. Seluruh fitur harus menjelaskan asal, status, kualitas, consent, dan keterbatasan data.

**Product Goal:** cyclist dapat merekam sesi latihan/balap dari awal hingga selesai tanpa kehilangan data pada perangkat yang didukung, membuka kembali sesi secara offline, meninjau ringkasan dan progres yang dapat ditelusuri ke aktivitas sumber, **merencanakan rute dengan profil elevasi**, dan **berinteraksi sosial (feed, klub, segmen) secara opt-in**. Email auth, biometrik lokal, Supabase, sensor, peta, dan fitur ekstensi melengkapi alur ini tanpa menghalangi ride capture.

**North-star metric:** jumlah ride tersinkron per pengguna aktif mingguan yang juga membuka minimal satu fitur sosial (feed/segmen/klub).

Target platform, perangkat sepeda yang didukung, provider kurs/cuaca, biaya, serta lingkungan deployment harus diputuskan sebelum integrasi. Rencana sprint di bawah adalah urutan usulan, bukan komitmen tanggal. Tile OpenStreetMap digunakan online dengan atribusi; penggunaan produksi, geocoding, dan routing tetap memerlukan evaluasi kebijakan/provider.

## 2. Konsep dan Batasan Produk

### Pengalaman inti

1. Cyclist menyiapkan sesi dan rute; peta tetap dapat dibuka sebelum ada GPX dan lokasi hanya diminta saat dibutuhkan.
2. Cyclist memulai rekaman dengan kontrol ringkas. Sampel lokasi/sensor yang tersedia ditandai sumber dan kualitasnya, disimpan lokal, dan tetap direkam saat layar mati sesuai kapabilitas platform/izin.
3. Setelah sesi, cyclist melihat ringkasan, membuka jejak pada peta, menelusuri riwayat, dan memahami agregat progres melalui sesi pembentuknya.
4. Custom login email dan biometrik menjaga akun/perangkat; akun cloud tidak menjadi prasyarat perekaman offline.
5. Logistik (kurs dan waktu dunia), AI analitik non-generatif, LLM percakapan, sensor, notifikasi, dan integrasi wearable mendukung perjalanan/latihan dengan data dan status yang transparan.
6. Tantangan strategi, leaderboard opt-in, serta proof blockchain adalah ekstensi opsional; kegagalannya tidak boleh mengganggu rekaman atau ringkasan lokal.

### Navigasi utama

Bottom navigation yang diusulkan:

| Tab | Isi utama |
| --- | --- |
| **Beranda** | Feed aktivitas cyclist, progres ringkas, status rekaman/sinkronisasi, peta, dan aksi utama. |
| **Jelajah** | Peta dan pencarian tempat/rute; pemilihan rute opsional dan kontrol sesi aktif terintegrasi di alur ini. |
| **Logistik / Tools** | Kurs mata uang dan waktu dunia untuk perjalanan/event; ekstensi companion yang tidak muat di alur inti. |
| **Profil** | Riwayat dan ringkasan sesi, rute tersimpan, akun, preferensi, izin, privasi, **Saran dan Kesan — Mata Kuliah Pemrograman Aplikasi Mobile**, penghapusan data, dan **Logout**. |

Gunakan empat destinasi utama yang sesuai dengan keputusan UX saat ini; sesi bukan tab terpisah. Aktivitas, ringkasan, dan persiapan rute tidak boleh tersembunyi di balik daftar menu generik. Logout bukan pengganti penghapusan akun atau data. Jika PO mengubah navigasi, perbarui dokumen dan UI dalam increment yang sama.

### Batasan keselamatan, privasi, dan kejujuran produk

- Email/password diverifikasi server-side melalui TLS; kata sandi hanya disimpan sebagai hash salted dan token sesi disimpan melalui secure storage platform.
- Biometrik di layar akun memverifikasi pengguna pada perangkat lalu memulihkan sesi cloud tersimpan; jangan memblokir seluruh aplikasi dengan layar unlock biometrik. Password tidak disimpan untuk alur ini. Jika tidak ada sesi tersimpan, gunakan login email/password; sign-out cloud mencabut sesi sehingga biometrik tidak dapat memulihkannya lagi.
- Enkripsi saat transit dan penyimpanan token adalah syarat dasar. Enkripsi database lokal at-rest dan manajemen kuncinya harus dibuktikan pada platform sasaran sebelum data sensitif dinyatakan terlindungi; jangan mengklaimnya hanya karena aplikasi memakai Supabase atau secure storage.
- Data lokasi dan sensor bersifat sensitif: minta izin saat relevan, kumpulkan seperlunya, batasi retensi, sediakan penghapusan/ekspor, dan jangan masukkan koordinat mentah ke log, analitik, prompt LLM, atau blockchain secara default.
- Rute dan sesi inti harus tetap dapat dibaca lokal tanpa jaringan. Status **tersimpan lokal**, **menunggu sinkronisasi**, dan **terkonfirmasi server** harus berbeda.
- Mini-game hanya untuk kondisi diam/aman; nonaktifkan atau tampilkan peringatan yang jelas jika sesi perjalanan sedang direkam. Tidak mendorong pengguna berinteraksi dengan layar saat bergerak.
- Tema aplikasi mengikuti mode appearance sistem: tema terang untuk mode terang dan palet gelap dengan permukaan gelap/teks terang untuk mode gelap.
- AI untuk klasifikasi/rekomendasi dan LLM generatif adalah dua fitur, pipeline, kriteria evaluasi, dan label UI yang terpisah.
- Blockchain bukan database perjalanan: simpan hash/bukti minimal saja setelah consent; jangan mencatat lokasi pribadi atau data akun on-chain. Tanpa jaringan/acknowledgment tidak boleh menyatakan proof terverifikasi.
- Push notification harus opt-in, dapat dimatikan per kategori, dan tidak memuat data lokasi sensitif di teks notifikasi.

## 3. Baseline dan Asumsi Implementasi

Repository saat ini mencakup Flutter app, perekaman sesi lokal, impor/ekspor GPX/JSON, ringkasan, sinkronisasi ringkasan dengan consent, custom login email, pemulihan sesi melalui login biometrik, fitur logistik, feedback, AI chat, gamifikasi rider (level/XP/gaya dan kustomisasi tampilan lokal), tim, leaderboard, dan ledger hash. Mini-game tantangan strategi **tidak** termasuk (lihat SP-16). Keberadaan kode/UI bukan bukti integrasi provider, akurasi data, atau perilaku background sudah lulus pada semua environment.

Status yang perlu diverifikasi lagi sebelum planning:

- Custom auth gateway email, secure session restore, dan refresh-token rotation tersedia di aplikasi; signing key Supabase, konfigurasi email, serta pengujian live pada project/perangkat nyata tetap harus diverifikasi sebelum dinyatakan siap.
- Login biometrik memulihkan refresh session perangkat setelah autentikasi biometrik lokal; biometrik tidak menggantikan verifikasi JWT server dan tidak menyimpan password.
- Sinkronisasi perjalanan ke Supabase mengirim metadata dan track GPS/telemetri mentah otomatis hanya setelah opsi persetujuan di Profil diaktifkan; penonaktifan menghentikan transfer selanjutnya tetapi tidak menghapus salinan cloud. Migrasi/RLS live dan perilaku integrasi belum diverifikasi.
- Basemap OpenStreetMap online ditampilkan di Beranda/Jelajah dan pada preview/panduan GPX; pusat awal peta saat ini Yogyakarta. Tile perlu internet; geocoding, pencarian rute online, turn-by-turn, dan provider tile produksi belum tersedia/diputuskan.
- Rute terpilih di Jelajah kini dapat mencari stasiun kereta, terminal, klinik/fasilitas kesehatan, dan bengkel sepeda melalui Overpass API; permintaan berjalan asinkron setelah konfirmasi eksplisit karena koordinat rute dikirim ke layanan publik. Hasil ditandai pada peta dan ditautkan ke OpenStreetMap. Cakupan radius/hasil bergantung pada sampling rute dan data OSM; kuota/ketahanan Overpass publik serta provider produksi masih harus dievaluasi.
- Panduan GPX menampilkan panah arah angin Open-Meteo relatif terhadap heading segmen rute, tanpa nilai kecepatan. Pengiriman koordinat GPS memerlukan persetujuan pada layar; permintaan disegarkan berkala/berdasarkan perpindahan. Ini indikator strategi rekreasi, bukan prakiraan mikroklimat atau fitur keselamatan; akurasi provider dan pengalaman lapangan belum diverifikasi.
- Panduan GPX dapat menampilkan satu Ghost Pacer kecil dari sesi selesai tercepat yang jejak GPS lokalnya cocok secara spasial dengan rute. Pencocokan mensyaratkan cakupan rute dan akurasi jejak minimum; sesi yang tidak cukup cocok tidak ditampilkan. Posisi dihitung dengan menormalkan waktu jejak ke durasi aktif sesi, termasuk rekaman lama tanpa identitas rute eksplisit; pause lama tidak dapat direkonstruksi persis. Fitur sepenuhnya lokal dan bukan replay/split timing presisi.
- Pratinjau rute GPX menyediakan briefing pra-perjalanan berbasis elevasi rute dan cuaca terkini setelah consent eksplisit. Titik awal dikirim ke Open-Meteo; ke Supabase/Gemini hanya dikirim ringkasan rute/elevasi/cuaca tanpa koordinat atau jejak rute lengkap. Briefing memakai kuota harian `rider-coach`; provider, quota, dan live deployment masih perlu diverifikasi.
- Auto-Visor menggunakan Android SensorManager melalui Flutter EventChannel native aplikasi, dengan ambang histeresis dan fallback tema normal; tema terang-terbaca `#071122` hanya membungkus layar gowes/panduan. Tidak menambah plugin KGP atau izin runtime. iOS fallback ke tema normal.
- Penyelesaian sesi menyimpan status completed ke Drift sebelum pekerjaan lanjutan. Konfirmasi UI menandai keberhasilan lokal dan status auto-sync; kegagalan refresh riwayat/ledger/sinkronisasi tidak mengubah ride menjadi gagal, dan upload cloud tetap dapat ditelusuri sebagai pending. Kegagalan storage inti tetap ditampilkan sebagai kegagalan.
- Konversi waktu kini memakai database zona waktu IANA lokal yang dapat dicari, termasuk penanganan waktu DST hilang/berulang; konversi kurs tetap hanya referensi harian/manual, bukan kurs live.
- Chat AI atau package/model lokal bukan bukti deployment LLM maupun AI ML yang tervalidasi.
- Progres aktivitas lokal sekarang menghitung frekuensi, jarak, dan durasi aktif untuk minggu/bulan berjalan, membandingkan periode kalender sebelumnya, dan menautkan agregat ke sesi selesai sumber. Target sesi/jarak/durasi mingguan/bulanan disimpan lokal. Elevasi agregat, metrik progres tambahan, serta validasi lengkap zona waktu/perangkat belum selesai.
- Sesi lokal kini memiliki judul, jenis, sumber pencatatan, migrasi Drift versi 8, edit metadata, ekspor arsip JSON seluruh sesi selesai beserta GPS, dan penghapusan sesi lokal. Ini bukan ekspor/penghapusan seluruh akun: profil, rute, preferensi, dan salinan cloud belum dicakup oleh lifecycle penuh.
- Feed aktivitas lokal, peta Beranda/Jelajah, dan layar gamifikasi rider (level/XP/gaya) telah memiliki UI. Workout interval lokal kini mendukung target waktu/jarak, cue yang dapat dimatikan, jeda, dan pemulihan sesi; pengujian layar mati/perangkat masih belum dilakukan. Hal tersebut tidak membuktikan kualitas produksi, akurasi ride capture background, integrasi push, AI analitik, atau proof blockchain.
- Karakter rider kini dapat memilih warna jersey dan aksesori; pilihannya tersimpan lokal dan dipakai di layar rider, Beranda, serta Profil. Appearance belum disinkronkan ke cloud atau ditampilkan pada karakter anggota tim lain.
- Notifikasi rute GPX lokal kini diuji untuk progres dan checkpoint, dan pengingat latihan dijadwalkan lokal dengan validasi izin serta pemulihan bila penjadwalan gagal. Ini bukan remote push FCM/APNs; perilaku notifikasi background tetap perlu uji perangkat nyata.
- Pelatih AI memiliki Edge Function yang mengirim ringkasan perjalanan tanpa koordinat GPS; consent diwajibkan untuk rekomendasi ride, sementara diagnosis konfigurasi model tidak mengirim konteks ride. Kode dan tipe sudah diperiksa, tetapi secret/provider deployment dan panggilan live belum diverifikasi.
- Ledger lokal membentuk rantai hash ringkasan sesi dan dapat memeriksa perubahan; sinkronisasi cloud opsional tersedia melalui fungsi database ber-auth. Ini bukan blockchain terdesentralisasi/on-chain, dan deployment cloud live belum dibuktikan.
- **Mini-game strategi reaksi (FR-11 lama) tidak ada lagi di aplikasi.** Migrasi Drift versi 8 menghapus tabel hasil game, dan tidak ada route/layar game di `app_router.dart`. Bila gamifikasi reaksi tetap diinginkan, ia harus direncanakan ulang sebagai PBI baru (lihat catatan di backlog), bukan diklaim sudah tersedia.
- Ride capture memakai konfigurasi lokasi background Geolocator (notifikasi foreground service di Android, background location mode di iOS) dan UI membedakan izin foreground dari “Sepanjang waktu”. Recovery mengubah sesi `recording` tersimpan menjadi `paused` saat startup. Ini bukan bukti keandalan saat layar mati, force-stop, atau proses OS dihentikan; uji device, baterai, interupsi, dan revokasi izin masih terbuka.
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
| SP-01 | **Autentikasi custom email dan lifecycle session** | Email/password diverifikasi server-side dengan hash salted, akun baru dapat langsung masuk tanpa email verification, access JWT memakai key dipercaya Supabase, refresh token disimpan hash-only server-side lalu dirotasi, dan logout mencabut refresh session. Password reset via email opsional dan hanya tersedia bila provider email dikonfigurasi; akun legacy tidak boleh dapat diklaim tanpa bukti kepemilikan. |
| SP-02 | **Login akun melalui biometrik** | Setelah login cloud berhasil, pengguna dapat memulihkan sesi tersimpan dengan biometrik dari layar akun tanpa menyimpan password. Aplikasi tidak menampilkan gerbang unlock global; sesi kedaluwarsa/revoked harus menghasilkan pesan jelas dan kembali ke login email/password; sign-out mencabut sesi tersimpan. |
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
| SP-14 | **Bottom navigation dan profil** | Empat tab Beranda/Jelajah/Logistik/Profil membuka alur utama dan mempertahankan state yang wajar; sesi dimulai dan dikendalikan dari Jelajah, bukan tab terpisah. Profil menyediakan preferensi, izin, privasi, **Saran dan Kesan — Mata Kuliah Pemrograman Aplikasi Mobile**, dan **Logout**. Form saran/feedback memvalidasi input, menampilkan acknowledgment nyata, dan menyatakan jika pengiriman offline/pending/gagal. |
| SP-15 | **Push notification berbasis mobile** | Pengguna memilih opt-in dan kategori; izin OS dapat ditolak/dicabut; token perangkat diikat ke akun secara aman dan dapat dihapus saat logout. Delivery/deep link/token kedaluwarsa/offline/duplikasi diuji. Push bukan kanal jaminan SOS dan payload lock-screen tidak menyertakan koordinat atau data sensitif. |
| SP-16 | **Tantangan strategi rute/balap** (belum diimplementasikan) | Skenario strategi rute/balap yang dimainkan saat berhenti; pilihan memberi trade-off/penjelasan dan skor disimpan lokal. Blokir game saat sesi merekam atau dijeda; tidak memberi instruksi real-time, klaim medis, atau saran keselamatan tervalidasi. **Status: tidak ada di aplikasi; migrasi Drift v8 menghapus tabel hasil game lama.** Harus dibangun ulang bila diinginkan. |
| SP-28 | **Ride-mode safety dan minimisasi distraksi** | Saat sesi aktif, tampilkan status/aksi capture yang besar dan jelas; hindari form atau alur kompleks; blokir game saat recording/paused; jangan mendorong chat/LLM ketika bergerak; state penting tidak hanya dibedakan oleh warna; tidak mengklaim SOS terkirim. Interaksi, semantics, touch target, interupsi, dan perilaku layar mati diuji pada device matrix; layar mati hanya dijanjikan jika background capture platform telah lulus validasi SP-21. |
| SP-26 | **Sensor sepeda eksternal** | Setelah protokol/perangkat sasaran diputuskan, pasangkan sensor BLE yang didukung (misalnya HR/cadence/speed/power) melalui profil standar relevan. Sampel menyimpan sumber, unit, waktu, dan kualitas; izin, disconnect/reconnect, stale data, range, duplikasi, dan consent sinkronisasi diuji. Sensor hilang tidak menghentikan rekaman lokal dan nilai tidak dibuat-buat. |
| SP-27 | **Integrasi wearable Garmin Health** | Alur pairing/consent, import metrik yang benar-benar disediakan API, deduplikasi dan pencabutan akses. PBI tetap blocked sampai approval partner dan credentials resmi tersedia; sebelum itu UI menyatakan belum tersedia dan tidak meminta kredensial palsu. Data diberi label sumber/waktu dan tidak disebut real-time tanpa dukungan provider. |

### P2 — Nilai tambahan setelah fondasi lulus

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-17 | **Proof perjalanan blockchain sederhana** | Target staging Polygon Amoy melalui relayer server-side. Dengan consent eksplisit, buat hash ringkasan terpilih (bukan lokasi mentah/identitas); simpan pending/confirmed/failed dan transaction reference. Uji kontrak, retry idempoten, dan verifikasi hash di Amoy. Produksi/mainnet menunggu uji biaya serta keputusan terpisah; tidak ada klaim immutable sebelum verifikasi. |
| SP-18 | **Pengingat hidrasi dan peringatan perubahan ride** | Pengguna dapat memilih pengingat hidrasi lokal dan peringatan rute/cuaca hanya jika sumber data benar tersedia. Frekuensi, quiet hours, volume/audio, timezone, offline, dismiss, serta kondisi ride diuji; data stale diberi label dan notifikasi tidak mengklaim incident/SOS delivery. |
| SP-19 | **Peningkatan peta dan layanan perjalanan** | Tambahkan POI/rute/fitur provider (misalnya geocoding, elevasi, atau reroute) hanya jika lisensi, biaya, kuota, atribusi, kualitas, dan cache/offline policy disetujui dan diuji. Evaluasi provider tile khusus sebelum trafik produksi; layanan tile publik tidak dianggap komitmen produksi. GPX offline tetap tersedia bila provider gagal. |
| SP-20 | **Leaderboard sesi mingguan opt-in** | Supabase/Postgres menyajikan dua peringkat Senin–Minggu UTC: durasi aktif terlama dan jarak terjauh dari sesi yang selesai. Fungsi PostgreSQL `SECURITY DEFINER` memvalidasi auth, consent, dan mengambil nilai hanya dari ringkasan milik pengguna yang telah tersinkron. Pengguna memilih opt-in dan alias publik. Hanya alias dan nilai kategori minggu berjalan yang dipublikasikan—tanpa email, lokasi, kontak, atau telemetri mentah. Tandai data sebagai laporan pengguna yang belum diverifikasi; uji RLS, opt-out/penghapusan, dan submission duplikat. |

### P1/P2 — Pilar Discover & Connect (visi "Strava untuk cyclist")

PBI ini mewujudkan [vision.md](vision.md) Pilar 2 dan 4. Provider dan free tier dirinci di [tech-stack.md](tech-stack.md). Seperti biasa, kegagalan fitur sosial tidak boleh mengganggu ride capture atau ringkasan lokal.

| ID | PBI | Hasil dan kriteria penerimaan |
| --- | --- | --- |
| SP-29 | **Perencanaan rute & profil elevasi** | Pengguna merencanakan rute di peta (mulai/tujuan/waypoint), melihat jarak + profil elevasi, dan menyimpannya; routing via BRouter/Valhalla (fallback ORS). Kegagalan provider tidak menghasilkan rute palsu; rute tersimpan dibuka offline; profil elevasi diberi sumber. |
| SP-30 | **Geocoding & pencarian tempat** | Autocomplete tempat/alamat via Photon (fallback Nominatim) dengan debounce, cache, atribusi, dan rate-limit; tidak ada hasil palsu saat gagal; izin lokasi hanya saat relevan. |
| SP-31 | **Feed aktivitas & profil publik** | Berbagi aktivitas opt-in ke feed; feed menampilkan item yang dibagikan saja; membedakan loading/kosong/offline/gagal; tidak memuat email/lokasi/telemetri mentah; berhenti berbagi menghapus item dari feed. |
| SP-32 | **Follow, kudos, komentar** | Ikuti/berhenti ikuti, kudos, komentar pada aktivitas yang dibagikan; komentar dapat dihapus penulis; kegagalan jaringan tidak dilaporkan sukses; ada blokir/lapor. |
| SP-33 | **Segmen & leaderboard segmen** | Buat segmen dari aktivitas/rute; matching effort dengan toleransi jelas (tidak palsu saat GPS buruk); leaderboard dihitung server-side dari upaya milik pengguna, opt-in, alias publik, hormati zona privasi; tandai belum diverifikasi. |
| SP-34 | **Tantangan (challenges)** | Ikut tantangan jarak/elevasi/konsistensi; progres dari sesi selesai unik dengan definisi periode/zona waktu jelas; opt-in, dapat ditinggalkan; tanpa klaim fitness/medis; agregat dapat ditelusuri. |
| SP-35 | **Zona privasi** | Kelola area sensitif yang memangkas titik awal/akhir pada keluaran yang dibagikan tanpa mengubah sampel lokal; tidak bocor via metadata. |
| SP-36 | **Impor kesehatan** | Impor dari Health Connect/HealthKit atau berkas FIT/TCX/GPX setelah izin; metrik menyertakan sumber/waktu; aktivitas impor dibedakan; ID stabil mencegah duplikasi; izin dapat dicabut. |
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
- Putuskan custom auth email, callback, session lifecycle, model user/RLS, local encryption decision, serta skenario logout/penghapusan.
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

- Kerjakan SP-01/SP-02 dengan custom email auth dan biometric session resume sebagai alur berbeda; uji registrasi/login langsung, resume sesi tersimpan, sesi kedaluwarsa/revoked, reset bila provider email tersedia, logout dan offline.
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
- **Identitas/data:** custom JWT/RLS dan session diuji dengan project nyata; RLS diuji lintas akun; logout, refresh rotation, revocation, ekspor, penghapusan lokal/cloud, backup dan restore diverifikasi.
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

## 9. Definition of Success dan Product Metrics

Product Goal dinilai dari outcome, bukan jumlah layar atau PBI yang ditutup. Catat nilai awal dari baseline sebelum PO menyetujui target; jangan menganggap contoh target berikut sebagai hasil yang telah dicapai.

| Outcome | Metrik dan definisi | Baseline | Target/release threshold | Bukti dan pemilik |
| --- | --- | --- | --- | --- |
| Ride tidak kehilangan data | Persentase skenario lifecycle yang memulihkan seluruh sampel yang telah di-acknowledge secara lokal; laporkan kehilangan maksimum dalam menit terpisah. | Diukur Sprint C pada device matrix. | Ditetapkan PO/Developers setelah baseline; blocker bila melanggar ambang yang disetujui. | Laporan device lifecycle; Developers. |
| Ringkasan dapat dipercaya | Persentase metrik deterministik summary yang sama dengan hasil hitung ulang fixture sumber. | Diukur Sprint D. | 100% untuk fixture deterministik yang disepakati. | Test report berisi fixture dan source activity; Developers. |
| Alur inti offline-first | Skenario persiapan lokal, rekam, buka kembali, ekspor, dan review yang tetap berjalan tanpa jaringan. | Diukur Sprint B. | Semua skenario inti lokal yang disepakati lulus. | Integration/device tests; Developers. |
| Status sync jujur | Item yang berstatus confirmed memiliki acknowledgment server; pending/retry tetap dapat ditemukan setelah restart. | Belum terbukti di staging. | 100% status sesuai acknowledgment dalam skenario tes. | API/integration test; Developers. |
| Privasi | Temuan risiko tinggi yang belum dimitigasi dalam scope release dan data sensitif yang tidak sengaja masuk log. | Audit awal release. | Nol temuan high-risk terbuka; nol payload sensitif pada log yang diuji. | Security/privacy review; PO dan Developers. |
| Operasi | Crash, kegagalan sync, biaya provider dan konsumsi baterai per jam pada workload yang ditetapkan. | Diukur sebelum release candidate. | Ambang disetujui setelah provider/device dipilih. | Dashboard dan laporan uji; owner ditentukan di dependency register. |

Setiap metrik harus menyebut numerator, denominator, periode, versi aplikasi/provider, device cohort, batas data, dan apakah pengumpulan bersifat opt-in. Jangan mengumpulkan lokasi mentah atau konten percakapan untuk mengukur produk tanpa justifikasi dan consent.

## 10. Matriks Platform dan Perangkat

Matriks ini menentukan arti "perangkat yang didukung". Baris TBD bukan dukungan yang telah dijanjikan. PO dan Developers mengisi serta menyetujui OS minimum, device reference, dan konfigurasi sebelum memilih PBI background/sensor sebagai scope Sprint.

| Platform | OS minimum | Device reference | GPS foreground/background | BLE/sensor | Biometrik | Push | Status/bukti |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Android | TBD — keputusan Sprint A | TBD — pilih model nyata | GPS foreground ada pada kode; background belum diverifikasi | Motion sensor tersedia melalui plugin; BLE belum dipilih/diuji | Plugin tersedia; matrix biometrik belum diuji | Izin deklaratif saja bukan bukti delivery | Belum release-supported; catat model, build OS, dan hasil uji sebelum mengubah status |
| iOS | TBD — keputusan Sprint A | TBD — pilih model nyata | Belum diverifikasi pada perangkat | Belum diverifikasi | Belum diverifikasi | Belum diverifikasi | Belum release-supported |

Catatan setiap uji perangkat memuat model, versi OS/build, versi Senapath, status izin, jaringan, kondisi baterai, provider, langkah reproduksi, hasil, dan keterbatasan. Dukungan vendor/OS lain tidak boleh diinferensikan dari satu model.

## 11. Kontrak Data Kanonis dan Provenance

Unit penyimpanan kanonis tidak berubah mengikuti locale atau pilihan imperial. Presentasi melakukan konversi di batas UI. Entity opsional yang belum menjadi kapabilitas produk boleh tetap berstatus planned; tabel ini adalah kontrak target untuk refinement SP-03/SP-04/SP-22/SP-23/SP-26/SP-27, bukan klaim bahwa semua tabel telah dibuat.

| Entity | Identitas/owner | Waktu, sumber, nilai | Status, lineage dan retensi |
| --- | --- | --- | --- |
| `User` | `userId` stabil; ownership akun server | Email dinormalisasi; tidak menyimpan password client-side | Server auth status; hapus sesuai siklus akun dan aturan legal yang disepakati. |
| `Activity` | `activityId` UUID stabil; `ownerId` nullable untuk data lokal sebelum akun | `startedAt`/`endedAt` UTC; timezone IANA asal bila diketahui; title/type; source `recorded`, `imported`, atau `manual` | Local/sync status, created/updated/deleted version; session/source IDs. |
| `ActivitySample` | `sampleId` stabil atau pasangan `(activityId, sequence)`; owner mewarisi Activity | `recordedAt` UTC; `source`; nilai kanonis/unit; quality/accuracy | Referensi Activity dan sequence untuk hitung ulang; telemetry mentah sensitif mengikuti retensi yang disetujui. |
| `LocationSample` | `sampleId`, `activityId` | Lat/lon WGS84, altitude meter, speed m/s, accuracy meter, timestamp UTC, source dan quality | Geometri terenkripsi sesuai desain; tidak disalin ke log, AI, leaderboard atau chain secara default. |
| `SensorSample` | `sampleId`, `activityId`, `sensorId` opsional | Jenis, nilai, unit SI, waktu, source, quality/staleness | Sensor eksternal/OS dibedakan; retensi/consent eksplisit. |
| `ActivitySummary` | `(ownerId, activityId)` stabil | Metrik turunan dengan unit kanonis, algoritma/versi dan waktu hitung | Setiap nilai menunjuk ke activity dan bila relevan subset sample; tidak mengubah raw samples. |
| `Workout` / `WorkoutInterval` | ID lokal stabil; owner lokal/cloud | Tipe durasi/jarak, urutan, batas/unit, cue | Versi dan referensi workout saat dipilih; cue opsional tidak memengaruhi capture jika gagal. |
| `SyncItem` | `syncItemId` stabil/idempotency key; entity type + entity ID | Created/updated UTC dan payload version | `local`, `pending`, `syncing`, `confirmed`, `failed`, atau `deleted`; simpan retry/ack timestamp tanpa payload sensitif di log. |
| `Consent` | `consentId`, `ownerId`, tujuan dan scope | Waktu UTC, versi notice, tindakan grant/revoke | Audit status consent; tidak menggunakan satu consent untuk tujuan lain. |
| `DeviceSession` | ID sesi perangkat; owner bila login | Token hanya di secure storage; expiry/rotation server | Revocation/clear status; jangan simpan password. |
| `ExternalSensor` | ID perangkat pseudonim + owner | Protocol/profile dan capabilities | Pairing/consent/revocation; jangan simpan identifier yang tidak dibutuhkan. |
| `AIInsight` | ID insight dan owner/activity refs | Model/rule version, input-period, calculatedAt | Label calculated/experimental, confidence/limitations, source IDs; dapat dihapus tanpa mengubah Activity. |
| `LLMContext` | Request ID pseudonim dan activity refs yang dipilih | Scope konteks, waktu, provider/model | Consent, retensi conversation, dan penghapusan terpisah dari AIInsight. |
| `NotificationPreference` | owner + category | Channel, locale/quiet hours bila didukung | Opt-in/revocation dan device-token status; token dihapus saat logout sesuai kebijakan. |

Setiap angka ditandai asalnya: `recorded`, `imported`, `manually_edited`, `calculated`, `ai_generated`, atau `externally_sourced`. Import GPX bukan rekaman aplikasi; edit metadata tidak mengubah sampel. Lineage minimal untuk agregat: `Weekly distance → [activityId A, activityId B, ...]`; bila filter/quality memengaruhi hasil, simpan aturan/versi dan jelaskan eksklusi. Data hilang tetap unknown, bukan nol.

### Status alur jaringan dan aktivitas

- Aktivitas lokal: `recording_local → paused_local → completed_local`.
- Sinkronisasi ringkasan: `completed_local → pending_sync → syncing → confirmed`; kegagalan menjadi `retryable_failed` atau `permanent_failed` beserta aksi berikutnya.
- Koneksi: `offline → online → syncing → partial_failure → retry → confirmed`; koneksi online tidak berarti data telah sync.
- Hanya acknowledgment server yang boleh menghasilkan `confirmed`. Retry menggunakan ID/idempotency key yang sama; UI tidak boleh menggabungkan state yang berbeda menjadi “tersimpan” tanpa penjelasan.

## 12. Konflik, Koreksi, Migrasi dan Versioning

Kebijakan awal untuk refinement (perubahan harus dicatat PO, bukan diputuskan diam-diam di repository):

| Kasus/field | Kebijakan |
| --- | --- |
| ID aktivitas, owner, waktu/sampel mentah dari rekaman | Immutable setelah commit lokal; koreksi sensor disimpan sebagai hasil turunan/anotasi dengan provenance, bukan overwrite diam-diam. |
| Judul, jenis, catatan metadata | Last-write-wins berdasarkan `updatedAt` server setelah clock normalization; simpan versi/revision dan laporkan konflik jika perubahan bersamaan tidak dapat direkonsiliasi. |
| Sampel/summary | Tidak di-merge dengan menjumlahkan dua salinan. Activity ID stabil + idempotency key membuat retry/upsert menjadi no-op atau update versi yang sama. |
| Delete vs pending update | Tombstone dengan revision lebih tinggi menang; pending update lama tidak boleh menghidupkan data kembali. Penghapusan cloud gagal harus tetap terlihat gagal/pending. |
| Import duplikat | Gunakan fingerprint geometri/waktu sebagai sinyal deteksi, bukan identitas otoritatif; minta konfirmasi bila kemungkinan duplikat dan jangan menghapus data berbeda otomatis. |
| Timeout setelah server mungkin menerima | Retry dengan idempotency key sama dan query/ack reconciliation sebelum menyatakan gagal final atau mengirim objek baru. |

Versi dan pemulihan:

- **Drift/local DB:** setiap perubahan menaikkan `schemaVersion`; migrasi upgrade diuji dari fixture versi sebelumnya, termasuk DB offline berisi sesi/route. Pertahankan data sampai migrasi dan verifikasi selesai; backup/copy sebelum migrasi destruktif.
- **Supabase:** migrasi SQL immutable, bernama/timestamp, dapat diulang hanya bila memang idempoten, dan diuji pada database kosong serta upgrade staging. Jangan mengubah migrasi yang telah diterapkan untuk environment bersama; buat migrasi korektif.
- **API/payload:** gunakan `schemaVersion`/API version, additive change terlebih dahulu, toleransi field opsional yang tidak dikenal, dan kebijakan minimum app version yang disetujui. Jangan menghapus field sebelum client lama di luar masa dukungan.
- **Kegagalan/rollback:** hentikan operasi tulis yang memakai schema tidak cocok, pertahankan ekspor lokal, tampilkan error yang dapat ditindaklanjuti, dan gunakan forward-fix untuk data cloud kecuali backup/restore rollback sudah diuji. Tentukan retention backup dan RPO/RTO sebelum production; saat ini TBD.

## 13. Threat Model dan Penyalahgunaan

Setiap PBI yang menyentuh ancaman di bawah harus menautkan test/evidence dan owner aktual pada refinement. “Owner” di tabel adalah peran sementara, bukan penugasan orang.

| Ancaman | Mitigasi minimum | Uji/bukti wajib | Owner |
| --- | --- | --- | --- |
| Perangkat dicuri | Biometrik perangkat opsional untuk resume; secure storage; logout/revoke; minimisasi data | Secure-storage/revoke test dan skenario perangkat hilang | Developers + PO (retensi) |
| Refresh token bocor/diulang | TLS, hash token server-side, rotasi atomik, expiry dan revoke | Replay token lama, expired dan concurrent refresh | Developers |
| Client memalsukan summary / IDOR antar-akun | Anggap client tidak tepercaya; validasi bounds; RLS/authorization server-side | Multi-account integration test, owner ID spoofing | Developers |
| Replay/duplikasi sync | ID stabil dan idempotency, acknowledgment terikat object/version | Retry setelah timeout dan duplicate submit | Developers |
| Leaderboard palsu | Ambil nilai dari sesi milik user yang selesai di server; consent; batas nilai; label belum diverifikasi | RPC auth, owner spoof, duplicate dan opt-out tests | Developers + PO |
| Prompt injection / data leakage LLM | Context eksplisit, minimisasi data, instruksi dianggap untrusted, provider/moderation/retention review | Adversarial prompt, no-consent, timeout dan delete test | Developers + PO |
| GPX berbahaya atau terlalu besar | Batas ukuran/point count/time, parser aman, validasi koordinat dan resource | Malformed XML, oversized, invalid coordinate, huge track | Developers |
| Storage exhaustion / payload mahal | Kuota, batas ukuran, rate limit, timeout, backpressure | Load/boundary/rate-limit tests dan alert | Developers + PO (biaya) |
| Abuse token push | Binding token ke akun, rotate/delete saat logout, minimal payload | Token stale/reused, cross-account dan logout test | Developers |
| Sensor spoof/stale data | Tandai source/quality/staleness; jangan klaim measurement verified | Missing, stale, out-of-range dan duplicate sample test | Developers |
| Proof blockchain palsu/privasi | Hash ringkasan minimal, consent, relayer terkontrol, verifikasi tx/hash | Test Amoy dan bukti tanpa raw location/account data | Developers + PO |

Threat model diperbarui saat provider, skema, atau data flow berubah; temuan high-risk yang belum dimitigasi memblokir release terkait atau harus dikecualikan eksplisit oleh PO dengan mitigasi dan pembatasan distribusi.

## 14. Test Pyramid, Traceability dan Review Evidence

Tes dipilih berdasarkan risiko, bukan hanya kemudahan. P0 wajib memiliki unit, integration, offline/restart, dan device lifecycle evidence pada platform yang diklaim; ekstensi cloud/provider wajib memiliki contract/RLS/failure tests; tidak ada mock yang dianggap bukti deployment.

| Lapisan | Cakupan | Contoh bukti |
| --- | --- | --- |
| Unit/domain | Lifecycle, unit/timezone, statistik/provenance, bounds, idempotency/state machine | Test report dan fixture/versioned expected output |
| Widget/UI | Loading/empty/error/offline/permission, navigasi/back, screen reader semantics, dynamic text/large targets | Widget test; screenshot opsional bukan pengganti assertion |
| Integration/local DB | Drift migration dari versi sebelumnya, encrypted store, restart, import/export, tombstone | Migration/integration test pada DB nyata atau fixture native |
| API/contract/security | Edge Function validation, timeout/error mapping, JWT, RLS multi-user, quota/rate limit | Staging response/test logs yang disanitasi |
| Device/lifecycle | Lock screen, background, interrupt/call, force-stop, permission revoke, recovery, GPS weak, battery | Device matrix dengan versi/build dan langkah reproduksi |
| Offline/transition | Airplane mode, online recovery, partial failure, retry, duplicate ack | State transition tests dan server acknowledgment evidence |
| Performance/battery | Durasi sesi, ukuran GPX/DB, memory, sampling/write rate, tile/network usage | Benchmark pada device reference dan threshold yang disetujui |
| Accessibility/safety | Semantics, contrast, color-independent states, touch targets, reduced motion, ride mode | Accessibility review/tool output dan device walkthrough |
| Exploratory/field | Alur persiapan → rekam → review pada kondisi lapangan aman | Sprint Review evidence dengan batasan dan consent |

Traceability wajib untuk setiap requirement/PBI yang diterima:

`FR/PBI → acceptance criterion ID → test case ID → commit/build/environment → hasil/evidence → keputusan Review`

Evidence tidak boleh memuat token, secret, alamat rumah/koordinat pribadi, atau konten percakapan. Catat kegagalan beserta issue/owner; jangan mengubah status test menjadi pass hanya karena UI terlihat benar.

### Accessibility, localization dan ride-mode safety lintas PBI

- Screen reader/semantics, kontras yang diuji, dukungan text scaling, target sentuh yang memadai, reduced motion, dan status yang tidak hanya dibedakan dengan warna berlaku pada P0 dan setiap layar yang diubah.
- Map tidak menjadi satu-satunya cara memahami jarak/status; status recording, permission, sync, serta sensor quality punya teks/semantics. Haptic/audio alternatif hanya jika tersedia, dapat dimatikan, dan tidak mengganggu.
- Simpan timestamp UTC dan IANA zone saat relevan; locale format tanggal/angka/mata uang hanya di presentasi. Satuan kanonis metric; preferensi metric/imperial mengubah tampilan saja. Bahasa awal, locale fallback, temperatur/cuaca, dan strategi translasi harus diputuskan Sprint A (saat ini TBD).
- **SP-28 — Ride-mode safety & distraction minimization:** kontrol capture besar dan terbatas; jangan membuka form/flow kompleks saat merekam; blokir game ketika sesi recording/paused; chat/LLM tidak mendorong interaksi saat bergerak; state recording dapat dikenali tanpa warna; layar mati tidak boleh menghentikan capture bila dukungan platform telah divalidasi; UI SOS tetap jujur dan tidak mengklaim pesan terkirim. Uji transisi sesi, ukuran teks/semantics, tap target, dan interupsi di device matrix.

### Budget performa dan baterai

Sebelum Sprint C PO/Developers menetapkan baseline dan threshold untuk battery drain per jam, GPS/sensor sampling, interval persistensi, memory, puncak ukuran DB, durasi/point maksimum aktivitas, batas GPX, volume tile/data, sync batch dan timeout. Hingga disetujui, nilai berstatus **TBD**, bukan jaminan. Uji memakai device reference, workload, durasi, kondisi layar/jaringan, dan ambang yang sama; perubahan budget perlu dicatat sebagai keputusan.

## 15. Hierarki Backlog

Gunakan **Epic → Feature → PBI → Task**. P0/P1/P2 adalah prioritas produk, bukan ukuran; SP-01 sampai SP-27 saat ini harus diperlakukan sebagai item/cluster backlog tingkat tinggi sampai dipecah, bukan otomatis sebagai PBI yang muat satu sprint.

- **Epic:** outcome besar lintas fitur, misalnya Reliable Ride Capture.
- **Feature:** kapabilitas yang memberi nilai terlihat, misalnya Background Recording atau Session Recovery.
- **PBI:** perubahan vertikal kecil yang dapat didemokan, punya actor/value, acceptance criteria teruji, owner keputusan, dependency, risiko, dan batas scope.
- **Task:** langkah engineering/test/documentation yang diperlukan menyelesaikan PBI; task sendiri bukan increment nilai pengguna.

Contoh pemecahan SP-21:

```text
Epic: Reliable Ride Capture
  Feature: Background Recording
    PBI: Simpan batch sampel secara periodik ketika layar mati
    PBI: Pulihkan sesi terputus sebagai paused setelah process restart
    PBI: Tampilkan dan tangani revokasi izin lokasi
    PBI: Validasi perilaku low-battery dan penghentian OS
```

Jangan menambah PBI baru sebelum refinement menghapus overlap, menetapkan dependency/owner, dan membedakan fungsi sudah ada, belum diuji, deployed, serta blocked. Pemecahan harus mempertahankan urutan nilai P0 dan tidak menjadikan cloud/provider prasyarat ride lokal.

## 16. Risk Register dan Decision/Dependency Register

Daftar berikut adalah starter register berdasarkan bukti repo saat ini. Probabilitas/impact harus ditinjau PO dan Developers; status “terbuka” bukan keputusan yang sudah dibuat. Setiap keputusan eksternal mencatat owner peran, gate/tanggal yang ditentukan tim, dependency, status, dan bukti keputusan.

### Product risk register

| Risiko | Probabilitas / dampak awal | Mitigasi | Trigger | Owner/status |
| --- | --- | --- | --- | --- |
| OS menghentikan capture background | Tinggi / kritis | Implementasi lifecycle resmi, checkpoint lokal, recovery, uji device dan komunikasi batas OS | Sesi terputus/kehilangan sampel pada lifecycle test | Developers; terbuka, SP-21 |
| GPS/sensor stale atau korup | Sedang / tinggi | Bounds, timestamp/source/quality, data missing sebagai unknown | Sampel invalid/stale atau jarak berbeda dari fixture | Developers; terbuka |
| Sync duplicate / status palsu | Sedang / tinggi | ID stabil, idempotency, ack reconciliation, state machine | Timeout/retry menghasilkan duplikasi atau confirmed tanpa ack | Developers; terbuka |
| RLS/auth salah konfigurasi | Sedang / kritis | JWT trust review, RLS multi-account, staging deployment gate | Cross-account read/write atau deploy migration gagal | Developers; staging belum terbukti |
| Key Google pernah terekspos | Tinggi / tinggi hingga dirotasi | Revoke/rotate, pisahkan server/SDK key, restrict API/app, cek penggunaan | Key lama masih aktif atau dipakai dari origin tak dikenal | PO/owner cloud; rotasi harus dikonfirmasi |
| Public OSM tile tak sesuai trafik produksi | Sedang / tinggi | Evaluasi lisensi/provider/cache/cost sebelum release publik | Volume/provider terms melewati batas | PO; terbuka |
| LLM cost/privacy atau prompt injection | Sedang / tinggi | Consent, quota, context minimization, provider review, fallback | Budget threshold atau adversarial leakage test gagal | PO + Developers; terbuka |
| Push/game mengganggu keselamatan | Rendah–sedang / tinggi | Opt-in, minimisasi payload, game block saat ride, ride mode | Interaksi saat sesi aktif atau pesan sensitif di lock screen | Developers; belum teruji end-to-end |
| Garmin partner approval tertunda | Tinggi / sedang | Tetap blocked/feature-gated; jangan meminta credential palsu | Approval/credential tidak ada saat planning SP-27 | PO; blocked |

### Decision/dependency register

| Keputusan/dependency | Owner peran | Gate | Dependency | Status |
| --- | --- | --- | --- | --- |
| Android/iOS minimum + device reference | PO + Developers | Sebelum komitmen SP-21/SP-26 | Perangkat uji dan akses lapangan | TBD |
| Local DB at-rest encryption, retention, RPO/RTO | PO + Developers | Sebelum klaim keamanan/release | Threat/data classification dan backup plan | TBD |
| Supabase staging, signing/JWT, email provider, RLS | Owner backend/PO + Developers | Sebelum SP-01/03/05 diterima | Secrets di Supabase, migration/deploy access | Kode ada; deployment belum diverifikasi |
| Google route/Maps keys, billing dan restriction | PO/owner cloud | Sebelum pencarian online dipromosikan | Key server/SDK terpisah, API enablement | Perlu verifikasi; key pernah dibagikan harus dirotasi |
| Provider map/tile production, kurs, LLM, push | PO | Sebelum scope production fitur provider | Lisensi, wilayah, kuota, biaya, privacy | Belum seluruhnya diputuskan |
| Sensor sepeda dan profil BLE | PO + Developers | Sebelum SP-26 | Hardware reference dan OS permissions | TBD |
| Garmin Health approval | PO | Sebelum SP-27 | Persetujuan partner + credential resmi | Blocked sampai tersedia |
| Polygon Amoy relayer/biaya | PO + Developers | Sebelum SP-17 | RPC/relayer, threat model, consent | Staging target; deployment belum dibuktikan |
| App signing, release account, monitoring/support owner | PO/Release owner | Sebelum release candidate | Store accounts/certificates, budget, runbook | TBD |

Keputusan yang mengubah scope/biaya/privacy dicatat dengan tanggal, opsi yang ditolak, alasan, approver, dan dampak backlog. Jangan memasukkan nilai secret ke register; referensikan secret manager/environment secara aman.
