# Kebutuhan Aplikasi Senapath

## 1. Tujuan dan Ruang Lingkup

Senapath adalah aplikasi pendamping latihan dan balapan sepeda. Aplikasi membantu pembalap menyiapkan rute, merekam sesi, memantau kondisi perjalanan, menangani keadaan darurat, dan meninjau hasil. Manajer tim dapat memakai fitur konversi untuk membantu persiapan logistik.

Dokumen ini mendefinisikan kebutuhan produk, bukan keputusan implementasi. Fitur yang bergantung pada peta, kurs, cuaca, AI, notifikasi jarak jauh, atau blockchain memerlukan pemilihan penyedia layanan dan koneksi jaringan.

## 2. Aktor

- **Pembalap**: mengelola profil, menyiapkan rute, merekam sesi, menerima peringatan, dan melihat hasil.
- **Manajer tim**: menggunakan alat konversi untuk mendukung perencanaan logistik.
- **Kontak darurat**: menerima pemberitahuan SOS jika pembalap tidak membatalkan hitung mundur.
- **Layanan eksternal**: penyedia peta, kurs, cuaca, AI, push notification, dan ledger blockchain sesuai integrasi yang dipilih.

## 3. Functional Requirements

### A. Akun dan Persiapan

**FR-01 — Login biometrik**  
Sistem harus menyediakan login biometrik pada perangkat yang mendukungnya. Saat biometrik tidak tersedia atau gagal, sistem harus menyediakan mekanisme pemulihan yang aman. Kredensial dan sesi lokal harus disimpan melalui fasilitas penyimpanan aman perangkat; data sensitif lokal harus dienkripsi.

**Kriteria penerimaan:** pengguna dapat masuk dengan biometrik yang terdaftar; penolakan biometrik tidak membuka sesi; pengguna dapat keluar dan sesi lokal tidak lagi dapat digunakan.

**FR-02 — Konversi mata uang**  
Sistem harus dapat mengonversi nilai EUR ke IDR, USD, dan CHF menggunakan kurs terbaru yang tersedia. Hasil harus menampilkan waktu pembaruan dan sumber kurs. Jika offline, sistem boleh menampilkan kurs tersimpan terakhir dengan penanda bahwa kurs tersebut bukan kurs real-time. Sistem juga harus menyediakan simulasi anggaran yang memungkinkan manajer menambahkan beberapa item pengeluaran dengan nama, nominal, dan mata uang, lalu melihat total dalam mata uang tujuan.

**Kriteria penerimaan:** pengguna dapat memasukkan nominal tunggal atau beberapa item anggaran dan melihat hasil/total dalam mata uang tujuan; item dapat diubah atau dihapus; kegagalan mengambil kurs tidak ditampilkan sebagai data real-time.

**FR-03 — Konversi zona waktu**  
Sistem harus mengonversi tanggal dan waktu acara dari zona waktu sumber (misalnya CEST) ke London, WIB, WITA, dan WIT. Konversi harus memperhitungkan perubahan daylight saving time dan pergantian tanggal.

**Kriteria penerimaan:** waktu tujuan dan tanggal lokal ditampilkan untuk setiap zona; perubahan tanggal dan aturan daylight saving tidak menghasilkan waktu yang keliru.

**FR-04 — Pencarian rute dan POI**  
Sistem harus memungkinkan pengguna mencari lokasi/rute, melihat peta dan informasi elevasi yang tersedia, serta melihat atau menandai POI seperti pos nutrisi dan pos medis. Rute yang telah diunduh harus dapat dibuka kembali tanpa jaringan.

**Kriteria penerimaan:** pencarian menampilkan hasil atau keadaan kosong/kegagalan yang jelas; POI terpilih dapat ditinjau pada rute; data rute offline diberi penanda waktu/sumber bila relevan.

**FR-05 — Saran strategi AI**  
Sistem harus dapat meminta saran yang mempertimbangkan data rute dan konteks yang tersedia, seperti elevasi, cuaca, dan preferensi pembalap. Sistem harus menyebutkan bila data tidak lengkap atau layanan tidak tersedia. Saran bersifat informatif, bukan diagnosis atau jaminan keselamatan.

**Kriteria penerimaan:** saran hanya menggunakan data yang tersedia dan dapat menampilkan kegagalan layanan; pengguna tidak diberi kesan bahwa saran menggantikan keputusan atau nasihat medis profesional.

### B. Perekaman dan Pemantauan Balapan

**FR-06 — Mulai, jeda, dan akhiri sesi**  
Sistem harus menyediakan kontrol untuk memulai, menjeda, melanjutkan, dan mengakhiri sesi. Sesi aktif harus menampilkan status perekaman dan metrik yang tersedia.

**FR-07 — Telemetri dan penyimpanan offline**  
Selama sesi, sistem harus merekam lokasi dan waktu, serta menghitung metrik perjalanan yang didukung perangkat, seperti jarak, durasi, kecepatan, dan elevasi. Data harus disimpan lokal secara berkala agar sesi tetap tercatat saat jaringan terputus, lalu disinkronkan ketika jaringan tersedia. Sistem harus menampilkan status sinkronisasi dan menangani unggahan ulang tanpa membuat duplikat.

**Kriteria penerimaan:** sesi tetap dapat direkam tanpa jaringan; data lokal tetap tersedia setelah aplikasi dibuka kembali; sinkronisasi tertunda dilanjutkan saat koneksi pulih.

**FR-08 — Pemanfaatan sensor**  
Sistem harus menggunakan GPS sebagai sumber utama posisi/pergerakan bila tersedia, barometer untuk estimasi perubahan tekanan/elevasi bila perangkat memilikinya, serta accelerometer dan gyroscope untuk gerakan/orientasi. Metrik turunan harus diberi label sumber dan status kualitas bila sensor tidak tersedia atau estimasinya tidak andal.

Cadence/RPM dan lean angle hanya boleh ditampilkan sebagai pengukuran/estimasi apabila algoritme dan perangkat telah divalidasi untuk kondisi tersebut. Accelerometer ponsel saja tidak boleh dianggap sebagai pengganti GPS yang akurat untuk kecepatan atau cadence tanpa validasi.

**FR-09 — Peringatan audio dan notifikasi**  
Sistem harus dapat memberikan peringatan audio lokal dan, bila diizinkan perangkat, notifikasi untuk kondisi yang relevan dengan sesi, seperti hidrasi atau perubahan rute/cuaca. Pengguna harus dapat mengatur jenis dan volume/frekuensi peringatan. Peringatan lokal yang sudah dijadwalkan harus tetap berfungsi tanpa jaringan; informasi terbaru dari layanan online harus menampilkan keterbatasan saat offline.

**FR-10 — Deteksi insiden dan SOS**  
Sistem harus mendeteksi pola gerakan yang berpotensi menunjukkan insiden berdasarkan sensor yang tersedia, lalu menampilkan alarm dan hitung mundur 15 detik. Pengguna harus dapat membatalkan hitung mundur. Jika tidak dibatalkan, sistem harus mencoba mengirim SOS beserta lokasi terakhir yang tersedia kepada kontak darurat dan menampilkan status pengiriman. Pengguna juga harus dapat memicu SOS secara manual.

**Kriteria penerimaan:** pembatalan menghentikan pengiriman SOS; kegagalan jaringan ditampilkan dengan jelas; deteksi sensor tidak boleh dinyatakan sebagai kepastian bahwa kecelakaan benar-benar terjadi.

### C. Istirahat dan Evaluasi Refleks

**FR-11 — Mini game reaksi pengereman**  
Sistem harus menyediakan mini game reaksi dengan durasi sesi dua menit, indikator visual yang meminta respons, dan pencatatan skor seperti waktu reaksi serta jumlah respons benar/salah. Setiap hasil harus otomatis disimpan di database lokal bersama stempel waktu agar tetap tersedia offline dan dapat digunakan untuk evaluasi tren di FR-12. Skor dapat dibandingkan dengan sesi pengguna sebelumnya.

**Kriteria penerimaan:** hasil dan waktu pencatatannya tetap tersedia setelah aplikasi ditutup dan dibuka kembali; hasil yang belum tersinkron tidak hilang saat offline.

**FR-12 — Evaluasi AI atas skor game**  
Jika layanan AI tersedia, sistem dapat merangkum tren skor dan memberi pengingat untuk beristirahat. Skor mini game tidak boleh digunakan sendirian untuk menyatakan pengguna layak atau tidak layak melanjutkan balapan.

### D. Finis dan Pasca-Balapan

**FR-13 — Ringkasan sesi**  
Setelah sesi diakhiri, sistem harus menyajikan ringkasan metrik yang tersedia, termasuk jarak, durasi, akumulasi elevasi, dan grafik kecepatan bila data mencukupi. Data yang hilang atau diestimasi harus ditandai.

**FR-14 — Proof of Completion berbasis blockchain**  
Dengan persetujuan pengguna, sistem harus dapat mengirim hash kriptografis dari berkas/ringkasan sesi ke ledger yang dipilih dan menyimpan referensi transaksi serta statusnya. Data pribadi dan rute rinci tidak boleh ditulis ke ledger publik. Jika layanan gagal, pengiriman harus berstatus tertunda dan dapat dicoba kembali.

Proof of Completion membuktikan integritas berkas yang didaftarkan, bukan dengan sendirinya membuktikan bahwa data sensor atau kejadian balapan benar secara fisik.

**FR-15 — Papan peringkat**  
Sistem harus menampilkan papan peringkat berdasarkan hasil yang memenuhi aturan yang ditetapkan dan menyediakan cara memeriksa referensi proof bila tersedia. Sistem harus menjelaskan hasil yang belum tersinkron atau belum terverifikasi dan tidak boleh menampilkan hasil tertunda seolah-olah sudah terverifikasi.

**FR-16 — Profil dan foto**  
Pengguna harus dapat melihat dan memperbarui informasi profil yang diizinkan serta mengganti foto profil dengan gambar dari perangkat.

**FR-17 — Saran dan kesan**  
Pengguna harus dapat mengirim umpan balik kepada tim pengembang dan melihat konfirmasi berhasil/gagal. Pengiriman harus menjelaskan bila jaringan diperlukan.

**FR-18 — Navigasi dan logout**  
Sistem harus menyediakan navigasi utama melalui bottom navigation, termasuk akses ke profil dan fitur inti. Logout harus menutup sesi aktif tanpa menghapus riwayat yang telah disimpan kecuali pengguna memilih penghapusan data.

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
Sistem harus memungkinkan pengguna mengekspor hasil sesi ke GPX atau JSON ke penyimpanan lokal perangkat, serta mengimpor berkas GPX rute untuk ditampilkan pada fitur pencarian rute. Berkas yang tidak valid atau tidak didukung harus ditolak dengan pesan yang dapat dipahami.

**Kriteria penerimaan:** berkas GPX yang diekspor dapat dibuka oleh aplikasi peta/navigasi yang mendukung GPX; berkas GPX rute yang valid dapat diimpor dan ditampilkan di aplikasi.

**FR-23 — Manajemen penyimpanan dan peta offline**  
Sistem harus menyediakan tampilan penggunaan penyimpanan lokal, termasuk ukuran database dan cache/peta offline, serta memungkinkan pengguna menghapus cache peta dan mengatur batas penyimpanan offline. Penghapusan cache tidak boleh menghapus sesi yang belum tersinkron atau riwayat balapan.

**Kriteria penerimaan:** pengguna dapat melihat penggunaan penyimpanan dan menghapus peta/cache; sesi yang belum tersinkron tetap tersedia setelah cache dibersihkan; batas penyimpanan offline yang dipilih diterapkan pada unduhan berikutnya tanpa menghapus data sesi secara diam-diam.

### F. Integrasi Perangkat Wearable

**FR-24 — Koneksi dan sinkronisasi data wearable**  
Sistem harus memungkinkan pengguna menghubungkan dan memutuskan koneksi dengan perangkat wearable atau akun layanan yang secara eksplisit didukung, misalnya Garmin jika akses API dan persetujuan layanan tersedia. Dengan izin pengguna, sistem dapat mengimpor atau menyinkronkan aktivitas dan metrik yang tersedia dari provider tersebut, seperti detak jantung, cadence, power, kecepatan, jarak, waktu, atau lokasi. Metrik harus menyertakan sumber, waktu, dan status kualitas; data wearable tidak boleh dianggap tersedia secara real-time atau tervalidasi bila provider/perangkat tidak mendukungnya. Sistem harus menangani pencabutan izin, koneksi terputus, kegagalan sinkronisasi, serta mencegah aktivitas duplikat. Data lokal yang belum tersinkron harus tetap tersedia offline.

**Kriteria penerimaan:** pengguna hanya dapat menghubungkan provider/perangkat yang dinyatakan didukung; persetujuan dan izin data diminta sebelum sinkronisasi; metrik yang diimpor menampilkan sumber/waktu dan keterbatasannya; pengguna dapat memutuskan koneksi atau mencabut akses; kegagalan dan status offline terlihat jelas; sinkronisasi ulang tidak menggandakan aktivitas atau menghapus data lokal.

## 4. Kebutuhan Nonfungsional

**NFR-01 — Keamanan:** data lokal sensitif dan kredensial sesi harus dilindungi dengan mekanisme aman platform dan enkripsi saat tersimpan. Rahasia/API key layanan eksternal tidak boleh ditanam di aplikasi klien.

**NFR-02 — Privasi:** aplikasi harus meminta izin yang relevan sebelum mengakses lokasi, sensor, notifikasi, kamera/galeri, menghubungkan wearable, atau mengirim SOS. Pengguna harus mengetahui data apa yang dibagikan, khususnya sebelum sinkronisasi wearable atau publikasi hasil ke blockchain/papan peringkat.

**NFR-03 — Ketahanan offline:** perekaman inti, penyimpanan sesi, pembatalan alarm SOS, dan akses ke rute yang sudah diunduh harus tetap berfungsi tanpa internet. Fitur eksternal harus menunjukkan status offline dan tidak menghilangkan data lokal.

**NFR-04 — Keandalan sinkronisasi:** sinkronisasi harus dapat dilanjutkan setelah gagal, tidak menggandakan sesi, dan mempertahankan data lokal sampai server mengonfirmasi penerimaan.

**NFR-05 — Usabilitas dan keselamatan:** kontrol utama selama bersepeda harus mudah dikenali dan meminimalkan interaksi yang memerlukan perhatian lama. Peringatan penting harus dapat dibedakan dari informasi biasa.

**NFR-06 — Kompatibilitas perangkat:** aplikasi harus menangani izin ditolak, sensor tidak tersedia, GPS lemah, aplikasi berjalan di latar belakang, keterbatasan baterai, serta perbedaan dukungan perangkat/protokol wearable secara terkontrol.

**NFR-07 — Transparansi data:** waktu/sumber kurs, sumber dan keterbatasan metrik sensor/wearable, status sinkronisasi, status pengiriman SOS, dan status transaksi ledger harus dapat diketahui pengguna.

## 5. Aturan Bisnis dan Batasan

- Waktu real-time, kurs terkini, cuaca terkini, AI, push notification jarak jauh, peta online, dan blockchain bergantung pada koneksi serta ketersediaan penyedia terkait.
- Database lokal yang dipilih adalah Drift di atas SQLite; kebutuhan produk tetap data lokal aman, tersedia offline, dan dapat disinkronkan. Strategi enkripsi, migrasi, serta backup/pemulihan ditetapkan dalam desain teknis.
- Sensor ponsel memiliki variasi akurasi berdasarkan perangkat, pemasangan, kalibrasi, dan kondisi jalan. UI harus membedakan pengukuran langsung dari estimasi.
- Pengiriman SOS otomatis bergantung pada izin dan konektivitas. Aplikasi harus memberi informasi yang jelas bila pesan belum dapat dikirim.
- Pencatatan ke blockchain bersifat tambahan setelah sesi selesai; kegagalannya tidak boleh menghapus atau menghalangi akses ke ringkasan lokal.

## 6. Ketergantungan yang Perlu Diputuskan

- Penyedia peta, data elevasi, geocoding, dan format unduh rute.
- Penyedia kurs dan frekuensi pembaruan kurs.
- Sumber cuaca, layanan AI/LLM, kebijakan retensi data, dan batas biaya.
- Mekanisme autentikasi awal, backend akun, dan penyimpanan/sinkronisasi data.
- Kanal pengiriman SOS, format pesan, daftar kontak, serta perilaku saat tidak ada jaringan.
- Provider wearable (misalnya Garmin), akses API/SDK dan persetujuan integrasi, metrik yang diizinkan, metode autentikasi, pencabutan akses, serta batas sinkronisasi.
- Jaringan blockchain, kontrak/format transaksi, biaya transaksi, dan aturan keikutsertaan papan peringkat.
- Perangkat sasaran minimum dan metode validasi algoritme sensor, khususnya cadence, lean angle, dan deteksi insiden.
