# Kebutuhan Aplikasi Senapath

## 1. Tujuan dan Ruang Lingkup

Senapath adalah companion untuk cyclist yang berlatih dan balapan. Nilai inti produk adalah satu siklus yang andal: **siapkan rute dan sesi → rekam aktivitas tanpa kehilangan data → tinjau hasil dan progres**. Peta/LBS, lokasi dan sensor mendukung siklus ini; keselamatan, kontrol pengguna, keterbacaan saat bergerak, dan penggunaan offline menjadi syarat lintas fitur.

Konversi mata uang/waktu, AI dan LLM, tantangan strategi, notifikasi, leaderboard, blockchain, serta integrasi wearable tetap menjadi requirement produk, tetapi merupakan fitur pendukung atau tahap lanjutan—bukan pengganti atau blocker bagi pencatatan sesi inti. Manajer tim merupakan persona sekunder untuk persiapan logistik.

Dokumen ini mendefinisikan kebutuhan produk, bukan keputusan implementasi. Fitur yang bergantung pada peta, kurs, cuaca, AI, notifikasi jarak jauh, atau blockchain memerlukan pemilihan penyedia layanan dan koneksi jaringan.

## 2. Aktor

- **Cyclist latihan/balap**: menyiapkan rute dan jenis sesi, merekam perjalanan, lalu meninjau aktivitas dan perubahan progres dari data yang tersedia.
- **Manajer tim (sekunder)**: menggunakan alat mata uang/waktu untuk perencanaan logistik.
- **Kontak darurat**: dapat dihubungi melalui tindakan telepon/WhatsApp yang dimulai pengguna; aplikasi tidak menyatakan pesan telah dikirim atau diterima.
- **Layanan eksternal**: penyedia peta, kurs, cuaca, AI, push notification, dan ledger blockchain sesuai integrasi yang dipilih.

### Urutan nilai produk

1. **Ride capture:** mulai/jeda/lanjutkan/akhiri, posisi dan kualitas data yang jelas, penyimpanan lokal, pemulihan setelah gangguan, dan perekaman saat layar mati sesuai dukungan platform.
2. **Ride review:** detail sesi, riwayat aktivitas, statistik agregat dan tren yang hanya dihitung dari data yang tersedia.
3. **Ride preparation:** peta yang selalu dapat dibuka, impor/pemilihan rute, detail dan kesiapan perjalanan.
4. **Companion extensions:** unit/logistik, sensor, pengingat, AI/LLM terpisah, tantangan strategi, leaderboard, proof blockchain, dan wearable sesuai consent serta bukti kesiapan.

Fitur ekstensi tidak boleh menghalangi rekaman lokal, mengarang kualitas data, atau menampilkan estimasi sebagai pengukuran terverifikasi.

## 3. Functional Requirements

### A. Akun dan Persiapan

**FR-01 — Akun cloud dan buka aplikasi**  
Pengguna dapat mendaftar dan masuk dengan email/password melalui Edge Function autentikasi Senapath; kredensial diverifikasi server-side dan password hanya disimpan sebagai hash PBKDF2 bersalt di `public.app_users`. Access JWT berumur pendek dan refresh token acak yang hash-nya disimpan server dirotasi serta disimpan di secure storage perangkat. JWT custom memakai signing key Supabase yang sama agar `auth.uid()` dan RLS tetap berlaku. Setelah login online pertama, pengguna dapat memakai biometrik untuk memulihkan sesi akun tersimpan tanpa menyimpan password. Biometrik bukan layar kunci global atau autentikasi server tersendiri. Reset password memakai token sekali-pakai melalui email. Sign-out mencabut dan menghapus sesi tersimpan; data lokal tetap ada.

**Kriteria penerimaan:** email/password invalid tidak dikirim; akun baru mendapat sesi segera tanpa verifikasi email; password tidak pernah disimpan sebagai plaintext atau ciphertext yang dapat dibalik; hash diverifikasi hanya server-side; refresh token dirotasi dan dapat dicabut; sesi dipulihkan dari secure storage aplikasi setelah verifikasi biometrik eksplisit; login biometrik hanya tersedia jika sesi tersimpan dan biometrik terdaftar; tidak ada gerbang biometrik global; reset password menampilkan hasil generik dan hanya tersedia jika provider email dikonfigurasi; akun legacy tanpa password tidak dapat diambil alih melalui registrasi tanpa bukti kepemilikan; kesalahan konfigurasi Edge Function menjelaskan secrets yang hilang tanpa mengklaim login berhasil; sign-out cloud mengakhiri sesi tanpa menghapus riwayat lokal; aplikasi tanpa Supabase tetap membuka fitur offline dengan status akun belum tersedia.

**FR-02 — Konversi mata uang**  
Sistem harus dapat mengonversi nilai EUR ke IDR, USD, dan CHF menggunakan kurs terbaru yang tersedia. Hasil harus menampilkan waktu pembaruan dan sumber kurs. Jika offline, sistem boleh menampilkan kurs tersimpan terakhir dengan penanda bahwa kurs tersebut bukan kurs real-time. Sistem juga harus menyediakan simulasi anggaran yang memungkinkan manajer menambahkan beberapa item pengeluaran dengan nama, nominal, dan mata uang, lalu melihat total dalam mata uang tujuan.

**Kriteria penerimaan:** pengguna dapat memasukkan nominal tunggal atau beberapa item anggaran dan melihat hasil/total dalam mata uang tujuan; item dapat diubah atau dihapus; kegagalan mengambil kurs tidak ditampilkan sebagai data real-time.

**FR-03 — Konversi zona waktu**  
Sistem harus dapat mencari dan memilih zona waktu IANA di seluruh dunia untuk sumber maupun satu atau lebih tujuan. Konversi harus memperhitungkan perubahan daylight saving time dan pergantian tanggal.

**Kriteria penerimaan:** pengguna dapat mencari kota/zona seperti `America/New_York`; waktu dan tanggal lokal serta offset ditampilkan untuk setiap tujuan; perubahan tanggal dan aturan daylight saving tidak menghasilkan waktu yang keliru; jam lokal yang hilang/berulang ditangani eksplisit.

**FR-04 — Pencarian, visualisasi, dan rute offline**  
Sistem harus menampilkan geometri rute yang dipilih, bukan hanya metadata. Pengguna dapat mengimpor GPX, melihat jalurnya di atas basemap OpenStreetMap online, jarak/elevasi yang tersedia, dan POI yang memang ada. Tile basemap memerlukan koneksi dan atribusi; jejak GPX lokal tetap dapat dibuka tanpa jaringan. Pencarian online, geocoding, elevasi, dan POI eksternal hanya tersedia jika provider terpisah telah dipilih, dikonfigurasi, dan dapat dijangkau. Rute yang diimpor/diunduh harus dapat dibuka kembali tanpa jaringan; geometri lokasi disimpan terenkripsi.

**Kriteria penerimaan:** membuka rute dengan geometri menampilkan basemap online, jalur, atribusi, dan titik awal/akhir; kegagalan tile menampilkan jalur GPX serta status yang jelas; rute lama tanpa geometri menampilkan keterbatasan yang jelas; pencarian/provider yang tidak tersedia tidak menampilkan data palsu; rute lokal dapat dibuka dalam mode pesawat tanpa basemap.

**FR-05 — Insight AI non-generatif untuk sesi dan rute**
Sistem dapat memberi insight non-generatif atas sesi dan rute berdasarkan data yang tersedia, seperti konsistensi volume, distribusi durasi, elevasi, dan konteks cuaca dari provider bila tersedia. Insight harus dapat ditelusuri ke periode dan sumber data, menyatakan data yang hilang, dan tidak menyimpulkan kesiapan medis, diagnosis, atau jaminan keselamatan. Evaluasi tren tantangan strategi di FR-12 adalah use case AI non-generatif terpisah dengan input dan evaluasinya sendiri. Asisten generatif/LLM diatur pada FR-32.

**Kriteria penerimaan:** saran hanya menggunakan data yang tersedia dan dapat menampilkan kegagalan layanan; pengguna tidak diberi kesan bahwa saran menggantikan keputusan atau nasihat medis profesional.

### B. Perekaman dan Pemantauan Balapan

**FR-06 — Mulai, jeda, dan akhiri sesi**  
Sistem harus menyediakan kontrol besar dan mudah dikenali untuk memulai, menjeda, melanjutkan, dan mengakhiri sesi. Cyclist dapat memberi nama dan memilih jenis aktivitas yang didukung, misalnya latihan luar ruang, balapan, atau indoor. Sesi aktif menampilkan status perekaman dan metrik yang tersedia; kontrol tidak memerlukan mengetik saat bergerak.

**Kriteria penerimaan:** transisi status valid dan dapat dipulihkan; jeda tidak menambah durasi/jarak; sesi yang pulih setelah app/process berhenti ditampilkan sebagai dijeda untuk konfirmasi, tidak diam-diam melanjutkan; label/judul aktivitas opsional tidak mengubah data ukur.

**FR-07 — Telemetri, outbox, dan sinkronisasi**  
Selama sesi, sistem merekam data yang diizinkan dan didukung perangkat ke penyimpanan lokal secara berkala. Outbox lokal bertahan melewati restart/offline. Sinkronisasi hanya boleh dimulai bila backend, akun, dan koneksi tersedia; item tetap lokal sampai server mengonfirmasi penerimaan. Setiap item memiliki ID stabil dan operasi retry idempotent.

**Kriteria penerimaan:** status `lokal`, `menunggu`, `mengirim`, `tersinkron`, dan `gagal` dapat dibedakan; tanpa konfigurasi backend UI menyatakan sinkronisasi belum tersedia; data lokal tidak hilang pada timeout/logout/restart; retry tidak membuat duplikat; hanya respons server terverifikasi yang menandai data tersinkron.

Perekaman lokal tidak mensyaratkan login atau jaringan. Sinkronisasi ringkasan atau telemetri hanya mengirim jenis data yang telah disetujui; sesi tetap dapat ditinjau lokal bila service, akun, atau server tidak tersedia.

**FR-08 — Pemanfaatan sensor**  
Sistem harus menggunakan GPS sebagai sumber utama posisi/pergerakan bila tersedia, barometer untuk estimasi perubahan tekanan/elevasi bila perangkat memilikinya, serta accelerometer dan gyroscope untuk gerakan/orientasi. Metrik turunan harus diberi label sumber dan status kualitas bila sensor tidak tersedia atau estimasinya tidak andal.

Cadence/RPM dan lean angle hanya boleh ditampilkan sebagai pengukuran/estimasi apabila algoritme dan perangkat telah divalidasi untuk kondisi tersebut. Accelerometer ponsel saja tidak boleh dianggap sebagai pengganti GPS yang akurat untuk kecepatan atau cadence tanpa validasi.

**FR-09 — Peringatan audio dan notifikasi**  
Sistem harus dapat memberikan peringatan audio lokal dan, bila diizinkan perangkat, notifikasi untuk kondisi yang relevan dengan sesi, seperti hidrasi atau perubahan rute/cuaca. Pengguna harus dapat mengatur jenis dan volume/frekuensi peringatan. Peringatan lokal yang sudah dijadwalkan harus tetap berfungsi tanpa jaringan; informasi terbaru dari layanan online harus menampilkan keterbatasan saat offline.

**FR-10 — Deteksi insiden dan SOS**  
Tindakan SOS manual melalui telepon atau draft WhatsApp tersedia sesuai dukungan perangkat. Keputusan produk saat ini: aplikasi tidak mengirim pesan otomatis dan tidak mengklaim pesan terkirim/diterima. Deteksi otomatis tetap nonaktif sampai algoritme, false-positive/false-negative, lifecycle background, dan alur pembatalannya divalidasi pada perangkat serta kondisi bersepeda representatif.

**Kriteria penerimaan:** pembatalan menghentikan handoff; UI membedakan handoff berhasil dibuka dari pesan yang benar-benar dikirim; kegagalan membuka aplikasi/channel ditampilkan; deteksi sensor tidak boleh dinyatakan sebagai kepastian kecelakaan.

### C. Istirahat dan Evaluasi Refleks

**FR-11 — Tantangan strategi rute/balap**

Mini-game reaksi visual diganti dengan tantangan strategi rute/balap berbasis skenario. Pengguna memilih tindakan dari beberapa opsi, menerima penjelasan trade-off, dan mendapat skor latihan yang disimpan lokal bersama waktu bermain. Game hanya dapat dimainkan saat tidak ada sesi yang sedang merekam atau dijeda; game tidak menggunakan input real-time saat bersepeda dan bukan saran keselamatan, medis, atau performa yang tervalidasi.

**Kriteria penerimaan:** skenario dapat dimainkan offline; jawaban, skor, dan waktu tersimpan setelah aplikasi ditutup/dibuka; permainan diblokir saat sesi aktif/jeda; UI menjelaskan bahwa jawaban adalah simulasi edukatif dan bukan instruksi balapan.

**FR-12 — Evaluasi AI atas hasil tantangan strategi**

Jika layanan AI non-generatif tersedia dan pengguna menyetujui, sistem dapat mengevaluasi tren kategori jawaban tantangan strategi serta merangkum pola belajar. AI tidak boleh menyimpulkan kelayakan/kemampuan fisik untuk balapan; hasil simulasi tidak dianggap sebagai catatan performa nyata.

### D. Finis dan Pasca-Balapan

**FR-13 — Ringkasan sesi**  
Setelah sesi diakhiri, sistem harus menyajikan detail/summary aktivitas yang tersedia: waktu, jenis sesi, jarak, durasi aktif, elevasi, grafik kecepatan, kualitas GPS, sumber sensor, dan status sync. Metrik yang tidak cukup datanya disembunyikan atau diberi label tidak tersedia; metrik turunan/estimasi diberi sumber dan kualitas. Dari summary pengguna dapat membuka sesi pada peta, ekspor data, atau memulai aksi lanjutan dengan consent.

**FR-14 — Proof of Completion berbasis blockchain**  
Target staging yang dipilih adalah jaringan EVM Polygon Amoy. Dengan persetujuan pengguna, sistem harus dapat mengirim hash kriptografis dari berkas/ringkasan sesi melalui relayer server-side dan menyimpan referensi transaksi serta statusnya. Data pribadi dan rute rinci tidak boleh ditulis ke ledger publik. Produksi/mainnet belum diputuskan; deploy kontrak, RPC, key relayer, batas biaya, dan verifikasi testnet masih prasyarat implementasi.

Proof of Completion membuktikan integritas berkas yang didaftarkan, bukan dengan sendirinya membuktikan bahwa data sensor atau kejadian balapan benar secara fisik.

**FR-15 — Papan peringkat**  
Papan peringkat bersepeda mingguan (minggu Senin–Minggu dalam UTC) memiliki dua kategori: durasi aktif terlama dalam satu sesi selesai dan jarak terjauh dalam satu sesi selesai. Submission hanya menggunakan ringkasan sesi milik pengguna yang telah disinkronkan, melalui fungsi PostgreSQL `SECURITY DEFINER` yang memverifikasi autentikasi, consent, dan batas nilai. Keikutsertaan wajib opt-in; identitas yang tampil adalah alias publik pilihan pengguna. Hanya alias dan nilai kategori minggu berjalan yang dipublikasikan—bukan email, kontak, lokasi, atau telemetri mentah. Nilai tetap diberi label laporan pengguna dan tidak diverifikasi independen; pengguna dapat opt-out untuk menghapus semua skornya.

**FR-16 — Profil dan foto**  
Pengguna harus dapat melihat dan memperbarui informasi profil yang diizinkan serta mengganti foto profil dengan gambar dari perangkat.

**FR-17 — Saran dan kesan**  
Pengguna harus menyetujui pengiriman, mengetahui tujuan dan retensi pesan, melihat status lokal/pending/berhasil/gagal, serta dapat mencoba ulang tanpa duplikasi. Kegagalan jaringan tidak boleh dilaporkan sebagai sukses. Isi pesan tidak boleh masuk log diagnostik.

**FR-18 — Navigasi, local lock, dan sign-out**  
Navigasi harus memberi akses jelas ke Beranda, Jelajah, Sesi, Logistik/Tools, dan Profil sesuai pola platform. Beranda memprioritaskan aktivitas terbaru, ringkasan progres, status rekaman/sinkronisasi, peta, dan aksi utama; bukan sekadar daftar menu. Local lock, sign-out akun cloud, dan penghapusan data adalah aksi berbeda. Sign-out membersihkan token dan state sensitif dari memori, membatalkan respons async yang terlambat, tetapi tidak menghapus sesi lokal kecuali diminta.

### E. Pengaturan dan Pengelolaan Data

**FR-19 — Manajemen kontak darurat**  
Sistem harus memungkinkan pengguna menambah, mengubah, dan menghapus 1 sampai 3 kontak darurat. Data kontak mencakup nama, nomor telepon atau WhatsApp, dan hubungan dengan pengguna; data harus disimpan secara aman di perangkat dan disinkronkan ke server saat tersedia. Deteksi insiden otomatis hanya dapat diaktifkan jika setidaknya satu kontak valid terdaftar.

**Kriteria penerimaan:** pengguna dapat mengelola maksimal tiga kontak; sistem menolak aktivasi deteksi insiden otomatis tanpa minimal satu kontak valid; data kontak lokal tetap terlindungi dan perubahan tertunda disinkronkan saat koneksi pulih.

**FR-20 — Pemeriksaan kesiapan pra-balapan**  
Sebelum sesi dimulai, sistem harus memeriksa izin lokasi dan notifikasi yang relevan serta ketersediaan GPS, accelerometer, dan gyroscope. Sistem harus memperingatkan pengguna jika izin lokasi ditolak, GPS belum mendapat fix yang memadai, sensor tidak tersedia, atau izin notifikasi belum diberikan. Sensor yang tidak memiliki mekanisme izin runtime harus diperiksa ketersediaannya, bukan ditampilkan sebagai izin yang ditolak.

**Kriteria penerimaan:** sebelum mulai, pengguna melihat status pemeriksaan; jika izin lokasi ditolak atau GPS belum memadai, sistem memberi peringatan yang jelas dan menjelaskan dampaknya pada perekaman. Pengguna dapat memperbaiki izin atau memilih melanjutkan dengan metrik yang terbatas bila perekaman masih memungkinkan.

**FR-21 — Pengaturan sistem satuan**  
Sistem harus menyediakan pilihan satuan Metrik (km, km/jam, meter) atau Imperial (mil, mph, kaki). Perubahan preferensi harus memperbarui tampilan metrik pada peta, sesi aktif, ringkasan, dan riwayat tanpa mengubah nilai dasar yang tersimpan.

**Kriteria penerimaan:** perubahan satuan berlaku pada seluruh tampilan yang relevan, termasuk riwayat; nilai dasar sesi tetap sama dan hanya format tampilannya yang dikonversi.

**FR-22 — Ekspor dan impor berkas sesi/rute**  
Sistem harus memungkinkan pengguna mengekspor hasil sesi ke GPX atau JSON ke penyimpanan lokal perangkat, serta mengimpor track/route GPX yang valid ke pustaka rute. Impor mempertahankan geometri, nama dan metadata yang tersedia; koordinat sensitif disimpan terenkripsi. Berkas besar, track tanpa titik, koordinat tidak valid, dan format tidak didukung harus ditolak dengan pesan yang dapat dipahami tanpa membuat rute setengah tersimpan.

**Kriteria penerimaan:** GPX yang diekspor dapat dibuka aplikasi kompatibel; GPX yang valid muncul di daftar, dapat dibuka sebagai geometri, dan tetap tersedia setelah restart/offline; kegagalan impor tidak meninggalkan record parsial; UI menunjukkan sumber serta metadata yang memang tersedia.

**FR-23 — Manajemen penyimpanan dan peta offline**  
Sistem harus menyediakan tampilan penggunaan penyimpanan lokal, termasuk ukuran database dan cache/peta offline, serta memungkinkan pengguna menghapus cache peta dan mengatur batas penyimpanan offline. Penghapusan cache tidak boleh menghapus sesi yang belum tersinkron atau riwayat balapan.

**Kriteria penerimaan:** pengguna dapat melihat penggunaan penyimpanan dan menghapus peta/cache; sesi yang belum tersinkron tetap tersedia setelah cache dibersihkan; batas penyimpanan offline yang dipilih diterapkan pada unduhan berikutnya tanpa menghapus data sesi secara diam-diam.

### F. Integrasi Perangkat Wearable

**FR-24 — Koneksi dan sinkronisasi data wearable**  
Provider awal yang dipilih adalah Garmin Health API langsung, dengan implementasi bergantung pada approval partner dan credentials dari Garmin. Setelah akses tersedia dan pengguna memberi izin, sistem dapat mengimpor aktivitas/metrik yang memang disediakan API. Metrik harus menyertakan sumber, waktu, dan status kualitas; data tidak boleh dianggap real-time bila API tidak mendukungnya. Sistem harus menangani pencabutan izin, koneksi terputus, kegagalan sinkronisasi, serta mencegah aktivitas duplikat. Sebelum approval, integrasi harus ditampilkan sebagai belum tersedia dan tidak boleh meminta kredensial Garmin palsu.

**Kriteria penerimaan:** pengguna hanya dapat menghubungkan provider/perangkat yang dinyatakan didukung; persetujuan dan izin data diminta sebelum sinkronisasi; metrik yang diimpor menampilkan sumber/waktu dan keterbatasannya; pengguna dapat memutuskan koneksi atau mencabut akses; kegagalan dan status offline terlihat jelas; sinkronisasi ulang tidak menggandakan aktivitas atau menghapus data lokal.

**FR-25 — Status layanan online**  
Untuk setiap fitur remote, sistem harus membedakan `belum dikonfigurasi`, `offline`, `memuat`, `tersedia`, dan `gagal`. Status harus berasal dari konfigurasi dan hasil operasi nyata, bukan sekadar keberadaan paket/dependency. Kegagalan provider tidak boleh menutupi data lokal atau menampilkan data lokal sebagai hasil online.

**Kriteria penerimaan:** build tanpa URL/key/provider tetap dapat menjalankan fitur lokal dan menyatakan integrasi belum dikonfigurasi; timeout, autentikasi ditolak, rate limit, dan respons invalid mendapat status yang dapat dipahami; hanya operasi yang diakui server yang ditampilkan berhasil.

**FR-26 — Panduan mengikuti rute**  
Pembalap dapat memulai dan mengakhiri panduan dari rute tersimpan. Selama panduan foreground, layar fokus mempertahankan basemap OpenStreetMap online (jika tersedia), visualisasi jalur, posisi GPS saat ini, progres, jarak tersisa, kualitas fix, dan status keluar jalur; layar dicegah tidur selama panduan aktif. Tile basemap tidak dijanjikan tersedia offline; jalur GPX lokal dan status GPS tetap terlihat tanpa koneksi. GPX track biasa tidak berisi instruksi belokan yang dapat dipercaya, sehingga sistem tidak boleh mengarang turn-by-turn. Dengan provider navigasi yang dipilih, aplikasi dapat menampilkan instruksi belokan/reroute sesuai kontrak provider.

**Kriteria penerimaan:** izin lokasi/GPS ditolak menghasilkan status dan opsi keluar yang jelas; kualitas GPS buruk tidak menghasilkan peringatan off-route palsu; posisi dan progres mengikuti geometri tersimpan; pengguna dapat mengakhiri panduan dan menghentikan stream/wakelock; panduan GPX tetap bisa dibuka offline; instruksi belokan hanya muncul dari provider/rute yang memang menyediakannya.

**FR-27 — Riwayat dan detail aktivitas bersepeda**
Cyclist dapat menemukan sesi selesai dari riwayat, membuka detail/summary, dan membedakan aktivitas hasil rekaman aplikasi dari aktivitas yang diimpor. Daftar dapat diurutkan menurut waktu serta difilter menurut jenis/asal aktivitas bila filter tersebut tersedia. Aktivitas memiliki ID stabil untuk mencegah duplikasi saat import/sync; perubahan judul/catatan tidak boleh mengubah nilai sensor atau lokasi.

**Kriteria penerimaan:** sesi tetap dapat dibuka setelah restart/offline; detail memperlihatkan tanggal lokal dan timestamp kanonis UTC bila diperlukan untuk sinkronisasi; sumber serta status lokal/cloud jelas; data yang tidak lengkap tetap ditandai; import/sync ulang tidak menggandakan sesi.

**FR-28 — Dashboard progres latihan**
Sistem menyajikan progres historis dari sesi selesai, sekurangnya jumlah aktivitas, jarak, durasi aktif, dan elevasi bila tersedia, untuk rentang waktu yang bisa dipilih (misalnya 7/30 hari dan rentang khusus). Cyclist dapat membandingkan periode yang sepadan dan melihat daftar aktivitas pembentuk agregat. Perhitungan menghormati unit pilihan dan tidak mencampur sesi ganda/impor yang sama. Insight hanya menyatakan pola faktual dari dataset yang tersedia; tidak mengklaim peningkatan fitness atau kesiapan balap tanpa metode tervalidasi.

**Kriteria penerimaan:** agregat cocok dengan sesi yang tercantum; perubahan rentang/unit memperbarui angka dan grafik konsisten; sesi dengan GPS/elevasi tidak memadai tidak diperlakukan sebagai nilai nol yang valid; state kosong, rentang parsial, data impor, offline, dan kegagalan load dibedakan; pengguna dapat membuka sumber data dari insight.

**FR-29 — Target aktivitas personal (opsional)**
Cyclist dapat membuat dan mengubah target sederhana berbasis pilihan sendiri (jumlah sesi, jarak, atau durasi per minggu/periode). Aplikasi menampilkan progres dan periode target dengan definisi waktu yang jelas. Target bukan resep latihan atau rekomendasi medis; target dapat dimatikan/dihapus dan tidak mengubah rekaman.

**Kriteria penerimaan:** agregat progres target memakai sesi selesai yang unik dan sama dengan dashboard; zona waktu/periode ditampilkan; tidak ada target default yang menyiratkan rekomendasi profesional; perubahan atau penghapusan target tidak menghapus riwayat aktivitas.

**FR-30 — Workout interval buatan cyclist**
Cyclist dapat menyusun rangkaian interval waktu atau jarak beserta pemulihan, menyimpannya lokal, lalu memilihnya sebelum sesi. Saat aktif, sistem memberi cue audio/haptic/visual yang dapat diatur dan tetap minim interaksi; jeda/akhiri sesi menyelaraskan timer workout dan tidak melanjutkan diam-diam setelah recovery aplikasi. Sistem menyediakan alat pencatat, bukan resep intensitas, target daya, atau nasihat medis.

**Kriteria penerimaan:** interval tervalidasi, urutan dan sisa waktu/jarak benar, pause/resume/finish dan layar mati diuji; cue dapat dimatikan; kehilangan GPS tidak membuat jarak workout palsu; workout tersedia offline; sesi rekaman tetap berjalan walau cue gagal.

**FR-31 — Sensor sepeda eksternal (kapabilitas lanjutan)**
Setelah protokol/perangkat sasaran disepakati, pengguna dapat memasangkan sensor bersepeda yang didukung (misalnya heart rate, cadence, speed, atau power melalui profil Bluetooth standar yang relevan). Setiap sampel mencatat sumber, waktu, unit, status koneksi/kualitas, dan tidak disamakan dengan sensor ponsel. Pairing/consent dapat dicabut; sensor yang terputus tidak menghentikan rekaman GPS/lokal.

**Kriteria penerimaan:** uji pairing, izin Bluetooth, disconnect/reconnect, sensor absen, data stale, unit/range dan duplikasi; nilai tidak dibuat-buat saat sensor tidak mengirim; data mentah hanya disinkronkan sesuai consent dan kebijakan retensi.

**FR-32 — Asisten LLM terpisah dari AI analitik**
Pengguna dapat bertanya kepada asisten generatif tentang rute atau aktivitas menggunakan konteks yang dipilih secara eksplisit. Sebelum data dikirim ke provider, aplikasi menjelaskan data yang dibagikan dan meminta consent. LLM tidak boleh menyamar sebagai hasil AI analitik FR-05/FR-12, mengarang data cuaca/rute/provider, atau memberi diagnosis dan instruksi keselamatan. Riwayat percakapan dapat dihapus; batas kuota, timeout, offline, dan kegagalan provider ditampilkan dengan jujur.

**Kriteria penerimaan:** permintaan tanpa consent tidak mengirim konteks personal; jawaban memisahkan fakta dari generasi dan menyatakan sumber/keterbatasan; kegagalan tidak menghasilkan jawaban sukses palsu; pengguna dapat menghapus percakapan sesuai kebijakan retensi yang dijelaskan.

## 4. Kebutuhan Nonfungsional

**NFR-01 — Keamanan:** data lokal sensitif dan kredensial sesi harus dilindungi dengan mekanisme aman platform dan enkripsi saat tersimpan. Rahasia/API key layanan eksternal tidak boleh ditanam di aplikasi klien.

**NFR-02 — Privasi:** aplikasi harus meminta izin yang relevan sebelum mengakses lokasi, sensor, notifikasi, kamera/galeri, menghubungkan wearable, atau mengirim SOS. Pengguna harus mengetahui data apa yang dibagikan, khususnya sebelum sinkronisasi wearable atau publikasi hasil ke blockchain/papan peringkat.

**NFR-03 — Ketahanan offline:** perekaman inti, penyimpanan sesi, pembatalan alarm SOS, dan akses ke rute yang sudah diunduh harus tetap berfungsi tanpa internet. Fitur eksternal harus menunjukkan status offline dan tidak menghilangkan data lokal.

**NFR-04 — Keandalan sinkronisasi:** sinkronisasi harus dapat dilanjutkan setelah gagal, tidak menggandakan sesi, dan mempertahankan data lokal sampai server mengonfirmasi penerimaan.

**NFR-05 — Usabilitas dan keselamatan:** kontrol utama selama bersepeda harus mudah dikenali dan meminimalkan interaksi yang memerlukan perhatian lama. Peringatan penting harus dapat dibedakan dari informasi biasa.

Panduan berkendara harus dapat dibaca sekilas, tidak memerlukan mengetik saat bergerak, menjaga target sentuh besar, dan menyarankan berhenti di tempat aman sebelum memeriksa ponsel. Panduan aplikasi bukan pengganti perhatian pada jalan atau perangkat navigasi yang tervalidasi.

**NFR-06 — Kompatibilitas perangkat:** aplikasi harus menangani izin ditolak, sensor tidak tersedia, GPS lemah, aplikasi berjalan di latar belakang, keterbatasan baterai, serta perbedaan dukungan perangkat/protokol wearable secara terkontrol.

**NFR-07 — Transparansi data:** waktu/sumber kurs, sumber dan keterbatasan metrik sensor/wearable, status sinkronisasi, status pengiriman SOS, dan status transaksi ledger harus dapat diketahui pengguna.

**NFR-08 — Kesiapan produksi:** klaim production-ready hanya berlaku pada platform/provider yang benar-benar dikonfigurasi dan lolos build rilis, migrasi, pengujian integrasi, audit secrets/RLS/izin, uji offline dan pemulihan, serta smoke test pada perangkat sasaran. Integrasi yang belum dideploy harus dinyatakan belum tersedia. Harus ada prosedur rollback, pemantauan kegagalan tanpa data sensitif, kebijakan retensi, dan kontak dukungan.

**NFR-09 — Keandalan rekaman dan konsumsi daya:** rekaman foreground/background harus mengikuti mekanisme resmi tiap OS, menjelaskan indikator/notifikasi permanen bila diwajibkan, dan pulih menjadi status aman setelah app/process dihentikan. Sampling, akurasi, interval persistensi, penggunaan baterai, panas, dan kehilangan data diuji pada perangkat sasaran dengan batas penerimaan yang ditetapkan melalui spike lapangan; tidak menjanjikan perekaman saat OS mencabut izin atau menghentikan service.

**NFR-10 — Kualitas insight dan keterlacakan:** setiap agregat/insight dapat ditelusuri ke sesi, rentang waktu, unit, sumber, dan jumlah data yang dipakai. Ketiadaan data tidak diubah menjadi nol; statistik deskriptif dipisahkan dari rekomendasi; AI tidak boleh memperkuat kesimpulan melebihi bukti inputnya.

**NFR-11 — UX saat bersepeda:** tindakan rekam utama memiliki target sentuh yang besar, label status yang terbaca sekilas, dan tidak mensyaratkan input teks saat bergerak. Pengaturan detail, chat, import, analisis, dan konfirmasi sensitif diarahkan dilakukan saat cyclist berhenti di tempat aman.

**NFR-12 — Kelayakan insight latihan:** Senapath bukan pengganti pelatih atau tenaga kesehatan. Target, interval, dan statistik adalah alat yang dipilih cyclist; AI/LLM tidak boleh menyimpulkan kemampuan medis, memberi diagnosis, atau menyatakan kesiapan lomba tanpa dasar tervalidasi dan scope yang disetujui.

## 5. Aturan Bisnis dan Batasan

- Waktu real-time, kurs terkini, cuaca terkini, AI, push notification jarak jauh, peta online, dan blockchain bergantung pada koneksi serta ketersediaan penyedia terkait.
- Database lokal yang dipilih adalah Drift di atas SQLite; kebutuhan produk tetap data lokal aman, tersedia offline, dan dapat disinkronkan. Strategi enkripsi, migrasi, serta backup/pemulihan ditetapkan dalam desain teknis.
- Sensor ponsel memiliki variasi akurasi berdasarkan perangkat, pemasangan, kalibrasi, dan kondisi jalan. UI harus membedakan pengukuran langsung dari estimasi.
- Pengiriman SOS otomatis bergantung pada izin dan konektivitas. Aplikasi harus memberi informasi yang jelas bila pesan belum dapat dikirim.
- Pencatatan ke blockchain bersifat tambahan setelah sesi selesai; kegagalannya tidak boleh menghapus atau menghalangi akses ke ringkasan lokal.
- Tidak ada status online/sinkron yang boleh disimpulkan dari UI atau dependency saja; perlu konfigurasi, autentikasi yang sesuai, dan acknowledgment server.

## 6. Ketergantungan yang Perlu Diputuskan

- Penyedia peta, data elevasi, geocoding, dan format unduh rute.
- Penyedia kurs dan frekuensi pembaruan kurs.
- Sumber cuaca, layanan AI/LLM, kebijakan retensi data, dan batas biaya.
- Mekanisme autentikasi awal, backend akun, dan penyimpanan/sinkronisasi data.
- Implementasi SOS otomatis tidak dipilih; kebijakan saat ini adalah handoff manual tanpa klaim delivery. Jika kebijakan berubah, pilih channel, persetujuan data lokasi, biaya, dan delivery tracking terlebih dahulu.
- Approval Garmin Health API, credentials, metrik yang diizinkan, metode autentikasi, pencabutan akses, serta batas sinkronisasi masih diperlukan sebelum FR-24 dapat diimplementasikan.
- Polygon Amoy dipilih untuk staging proof. Deploy kontrak/RPC/relayer dan biaya produksi/mainnet masih perlu diuji/diputuskan; leaderboard dipilih menggunakan Supabase dengan opt-in, alias, dan skor permainan saja.
- Perangkat sasaran minimum dan metode validasi algoritme sensor, khususnya cadence, lean angle, dan deteksi insiden.
