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

**FR-01 — Akun cloud dan buka aplikasi**  
Pengguna dapat mendaftar dan masuk dengan email/password melalui Supabase Auth. Bila verifikasi email diwajibkan, UI menjelaskan bahwa pengguna harus memverifikasi sebelum masuk. Pengguna dapat meminta reset password melalui email. Password hanya dikirim melalui koneksi TLS ke Supabase Auth; aplikasi tidak menyimpan password atau menulisnya ke tabel profil. Biometrik/PIN perangkat tetap _local unlock_, terpisah dari identitas cloud. Sign-out cloud mencabut sesi online; local lock tidak menghapus data lokal.

**Kriteria penerimaan:** email/password invalid tidak dikirim; sukses/gagal/menunggu verifikasi dibedakan; sesi Supabase dipulihkan dari secure storage SDK; reset password mengungkapkan hasil generik yang tidak membocorkan keberadaan email; sign-out cloud mengakhiri sesi tanpa menghapus riwayat lokal; aplikasi tanpa Supabase tetap membuka fitur offline dengan status akun belum tersedia.

**FR-02 — Konversi mata uang**  
Sistem harus dapat mengonversi nilai EUR ke IDR, USD, dan CHF menggunakan kurs terbaru yang tersedia. Hasil harus menampilkan waktu pembaruan dan sumber kurs. Jika offline, sistem boleh menampilkan kurs tersimpan terakhir dengan penanda bahwa kurs tersebut bukan kurs real-time. Sistem juga harus menyediakan simulasi anggaran yang memungkinkan manajer menambahkan beberapa item pengeluaran dengan nama, nominal, dan mata uang, lalu melihat total dalam mata uang tujuan.

**Kriteria penerimaan:** pengguna dapat memasukkan nominal tunggal atau beberapa item anggaran dan melihat hasil/total dalam mata uang tujuan; item dapat diubah atau dihapus; kegagalan mengambil kurs tidak ditampilkan sebagai data real-time.

**FR-03 — Konversi zona waktu**  
Sistem harus dapat mencari dan memilih zona waktu IANA di seluruh dunia untuk sumber maupun satu atau lebih tujuan. Konversi harus memperhitungkan perubahan daylight saving time dan pergantian tanggal.

**Kriteria penerimaan:** pengguna dapat mencari kota/zona seperti `America/New_York`; waktu dan tanggal lokal serta offset ditampilkan untuk setiap tujuan; perubahan tanggal dan aturan daylight saving tidak menghasilkan waktu yang keliru; jam lokal yang hilang/berulang ditangani eksplisit.

**FR-04 — Pencarian, visualisasi, dan rute offline**  
Sistem harus menampilkan geometri rute yang dipilih, bukan hanya metadata. Pengguna dapat mengimpor GPX, melihat jalurnya di atas basemap OpenStreetMap online, jarak/elevasi yang tersedia, dan POI yang memang ada. Tile basemap memerlukan koneksi dan atribusi; jejak GPX lokal tetap dapat dibuka tanpa jaringan. Pencarian online, geocoding, elevasi, dan POI eksternal hanya tersedia jika provider terpisah telah dipilih, dikonfigurasi, dan dapat dijangkau. Rute yang diimpor/diunduh harus dapat dibuka kembali tanpa jaringan; geometri lokasi disimpan terenkripsi.

**Kriteria penerimaan:** membuka rute dengan geometri menampilkan basemap online, jalur, atribusi, dan titik awal/akhir; kegagalan tile menampilkan jalur GPX serta status yang jelas; rute lama tanpa geometri menampilkan keterbatasan yang jelas; pencarian/provider yang tidak tersedia tidak menampilkan data palsu; rute lokal dapat dibuka dalam mode pesawat tanpa basemap.

**FR-05 — Saran strategi AI**  
Sistem harus dapat meminta saran yang mempertimbangkan data rute dan konteks yang tersedia, seperti elevasi, cuaca, dan preferensi pembalap. Sistem harus menyebutkan bila data tidak lengkap atau layanan tidak tersedia. Saran bersifat informatif, bukan diagnosis atau jaminan keselamatan.

**Kriteria penerimaan:** saran hanya menggunakan data yang tersedia dan dapat menampilkan kegagalan layanan; pengguna tidak diberi kesan bahwa saran menggantikan keputusan atau nasihat medis profesional.

### B. Perekaman dan Pemantauan Balapan

**FR-06 — Mulai, jeda, dan akhiri sesi**  
Sistem harus menyediakan kontrol untuk memulai, menjeda, melanjutkan, dan mengakhiri sesi. Sesi aktif harus menampilkan status perekaman dan metrik yang tersedia.

**FR-07 — Telemetri, outbox, dan sinkronisasi**  
Selama sesi, sistem merekam data yang diizinkan dan didukung perangkat ke penyimpanan lokal secara berkala. Outbox lokal bertahan melewati restart/offline. Sinkronisasi hanya boleh dimulai bila backend, akun, dan koneksi tersedia; item tetap lokal sampai server mengonfirmasi penerimaan. Setiap item memiliki ID stabil dan operasi retry idempotent.

**Kriteria penerimaan:** status `lokal`, `menunggu`, `mengirim`, `tersinkron`, dan `gagal` dapat dibedakan; tanpa konfigurasi backend UI menyatakan sinkronisasi belum tersedia; data lokal tidak hilang pada timeout/logout/restart; retry tidak membuat duplikat; hanya respons server terverifikasi yang menandai data tersinkron.

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
Pengguna harus menyetujui pengiriman, mengetahui tujuan dan retensi pesan, melihat status lokal/pending/berhasil/gagal, serta dapat mencoba ulang tanpa duplikasi. Kegagalan jaringan tidak boleh dilaporkan sebagai sukses. Isi pesan tidak boleh masuk log diagnostik.

**FR-18 — Navigasi, local lock, dan sign-out**  
Navigasi harus memberi akses jelas ke fitur inti dan kondisi penggunaannya. Local lock, sign-out akun cloud, dan penghapusan data adalah aksi berbeda. Sign-out membersihkan token dan state sensitif dari memori, membatalkan respons async yang terlambat, tetapi tidak menghapus data lokal kecuali diminta.

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
Sistem harus memungkinkan pengguna menghubungkan dan memutuskan koneksi dengan perangkat wearable atau akun layanan yang secara eksplisit didukung, misalnya Garmin jika akses API dan persetujuan layanan tersedia. Dengan izin pengguna, sistem dapat mengimpor atau menyinkronkan aktivitas dan metrik yang tersedia dari provider tersebut, seperti detak jantung, cadence, power, kecepatan, jarak, waktu, atau lokasi. Metrik harus menyertakan sumber, waktu, dan status kualitas; data wearable tidak boleh dianggap tersedia secara real-time atau tervalidasi bila provider/perangkat tidak mendukungnya. Sistem harus menangani pencabutan izin, koneksi terputus, kegagalan sinkronisasi, serta mencegah aktivitas duplikat. Data lokal yang belum tersinkron harus tetap tersedia offline.

**Kriteria penerimaan:** pengguna hanya dapat menghubungkan provider/perangkat yang dinyatakan didukung; persetujuan dan izin data diminta sebelum sinkronisasi; metrik yang diimpor menampilkan sumber/waktu dan keterbatasannya; pengguna dapat memutuskan koneksi atau mencabut akses; kegagalan dan status offline terlihat jelas; sinkronisasi ulang tidak menggandakan aktivitas atau menghapus data lokal.

**FR-25 — Status layanan online**  
Untuk setiap fitur remote, sistem harus membedakan `belum dikonfigurasi`, `offline`, `memuat`, `tersedia`, dan `gagal`. Status harus berasal dari konfigurasi dan hasil operasi nyata, bukan sekadar keberadaan paket/dependency. Kegagalan provider tidak boleh menutupi data lokal atau menampilkan data lokal sebagai hasil online.

**Kriteria penerimaan:** build tanpa URL/key/provider tetap dapat menjalankan fitur lokal dan menyatakan integrasi belum dikonfigurasi; timeout, autentikasi ditolak, rate limit, dan respons invalid mendapat status yang dapat dipahami; hanya operasi yang diakui server yang ditampilkan berhasil.

**FR-26 — Panduan mengikuti rute**  
Pembalap dapat memulai dan mengakhiri panduan dari rute tersimpan. Selama panduan foreground, layar fokus mempertahankan basemap OpenStreetMap online (jika tersedia), visualisasi jalur, posisi GPS saat ini, progres, jarak tersisa, kualitas fix, dan status keluar jalur; layar dicegah tidur selama panduan aktif. Tile basemap tidak dijanjikan tersedia offline; jalur GPX lokal dan status GPS tetap terlihat tanpa koneksi. GPX track biasa tidak berisi instruksi belokan yang dapat dipercaya, sehingga sistem tidak boleh mengarang turn-by-turn. Dengan provider navigasi yang dipilih, aplikasi dapat menampilkan instruksi belokan/reroute sesuai kontrak provider.

**Kriteria penerimaan:** izin lokasi/GPS ditolak menghasilkan status dan opsi keluar yang jelas; kualitas GPS buruk tidak menghasilkan peringatan off-route palsu; posisi dan progres mengikuti geometri tersimpan; pengguna dapat mengakhiri panduan dan menghentikan stream/wakelock; panduan GPX tetap bisa dibuka offline; instruksi belokan hanya muncul dari provider/rute yang memang menyediakannya.

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
- Kanal pengiriman SOS, format pesan, daftar kontak, serta perilaku saat tidak ada jaringan.
- Provider wearable (misalnya Garmin), akses API/SDK dan persetujuan integrasi, metrik yang diizinkan, metode autentikasi, pencabutan akses, serta batas sinkronisasi.
- Jaringan blockchain, kontrak/format transaksi, biaya transaksi, dan aturan keikutsertaan papan peringkat.
- Perangkat sasaran minimum dan metode validasi algoritme sensor, khususnya cadence, lean angle, dan deteksi insiden.
