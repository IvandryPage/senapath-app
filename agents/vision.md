# Visi Besar Senapath — "Strava untuk Cyclist"

> Dokumen ini adalah bintang utara produk. Semua dokumen lain ([requirements.md](requirements.md), [architecture.md](architecture.md), [tech-stack.md](tech-stack.md), [scrum-guide.md](scrum-guide.md), [visual.md](visual.md)) harus konsisten dengan visi di sini.

## 1. Tujuan Besar (North Star)

Senapath adalah **rumah digital untuk cyclist**: satu aplikasi tempat cyclist *merekam* setiap ride dengan andal, *menemukan dan merencanakan* rute, *berlatih* dengan tujuan, dan *terhubung* dengan komunitas cyclist lain — tanpa dinding berbayar, tanpa mengorbankan privasi, dan tanpa mengarang data.

Jika Strava adalah jejaring sosial kebugaran umum, Senapath adalah **Strava yang fokus sepeda dan beretika data**:

- dibangun khusus untuk dinamika bersepeda (segmen tanjakan, klub, rute gravel, elevasi, kadens/daya bila tersedia);
- biaya operasional ditekan dengan tumpukan **gratis / open-source** (lihat [tech-stack.md](tech-stack.md));
- pengguna memegang kendali penuh atas datanya (ekspor, hapus, zona privasi).

**North-star metric:** jumlah ride tersinkron per pengguna aktif mingguan yang juga membuka minimal satu fitur sosial (feed / segmen / klub). Metrik ini mengukur siklus inti **rekam → bagikan → kembali**, bukan jumlah layar.

## 2. Empat Pilar Produk

Visi ini bukan daftar fitur acak; ia adalah empat pilar yang saling menguatkan.

| Pilar | Janji ke cyclist | Kapabilitas kunci |
| --- | --- | --- |
| **1. Ride** (Rekam & Tinjau) | "Ride saya tidak pernah hilang." | Perekaman GPS/sensor offline-first, pemulihan sesi, ringkasan & riwayat yang jujur, ekspor GPX/JSON. |
| **2. Discover & Plan** (Jelajah & Rencana) | "Saya tahu ke mana dan seberapa berat." | Peta, perencanaan & impor rute, profil elevasi, panduan mengikuti rute, **segmen**. |
| **3. Train** (Latih) | "Saya paham progres saya, tanpa dikarang." | Dashboard progres, target pribadi, workout interval, analitik & AI yang dapat ditelusuri ke data sumber. |
| **4. Connect** (Sosialisasi) | "Saya tidak bersepeda sendirian." | Feed aktivitas, follow, kudos, komentar, klub/tim, tantangan, leaderboard segmen, berbagi rute. |

## 3. Cara Senapath Berbeda dari Strava

Kita mengambil yang terbaik dari Strava dan menolak yang tidak sesuai nilai produk.

| Aspek | Strava | Senapath |
| --- | --- | --- |
| Fokus | Kebugaran umum (lari, sepeda, renang, gym) | **Cycling-first**; keputusan fitur mengikuti kebutuhan cyclist. |
| Biaya | Banyak fitur inti di balik langganan | **Fitur analitik & sosial inti gratis**; biaya ditekan dengan tumpukan gratis/OSS. |
| Privasi | Data lokasi digunakan luas; kontrol terbatas | **Zona privasi**, opt-in per fitur, ekspor & hapus penuh, tanpa menjual lokasi mentah. |
| Offline | Online-first | **Offline-first**: rekam, buka rute, dan tinjau tidak butuh jaringan/akun. |
| Kejujuran data | Estimasi/segment matching pihak ketiga | Setiap angka diberi **sumber, kualitas, dan provenance**; estimasi diberi label. |
| AI | Fitur generatif tertutup | AI **dapat ditelusuri** ke data input, dipisah dari nasihat medis, dan memakai model gratis. |

## 4. Prinsip yang Tidak Bisa Ditawar

1. **Offline-first.** Merekam dan membaca data inti tidak boleh bergantung pada jaringan atau akun cloud. Sinkronisasi memperkaya, bukan menjadi syarat.
2. **Kepemilikan data.** Pengguna dapat mengekspor dan menghapus seluruh datanya. Data lokasi mentah tidak pernah dijual, dipublikasikan, atau dikirim ke pihak ketiga secara default.
3. **Kejujuran data.** Estimasi diberi label dan sumber; tidak ada klaim "terverifikasi" tanpa bukti; AI/LLM tidak menggantikan nasihat medis atau keputusan keselamatan.
4. **Cycling-first.** Prioritas fitur mengikuti dunia sepeda: segmen tanjakan, klub, rute, elevasi, gravel, cuaca angin.
5. **Biaya berkelanjutan.** Utamakan tumpukan gratis/OSS; setiap provider berbayar harus dibenarkan, diisolasi di balik adapter, dan punya fallback (lihat [tech-stack.md](tech-stack.md)).
6. **Privasi sejak awal.** Izin tepat waktu, consent mendahului pengiriman, zona privasi untuk area sensitif.
7. **Keselamatan mengalahkan kelengkapan.** Aplikasi tidak mendorong interaksi saat bergerak dan tidak mengklaim SOS terkirim tanpa konfirmasi.

## 5. Seperti Apa "Tercapai" Itu

Visi dianggap tercapai ketika semua pernyataan berikut benar dan dapat dibuktikan:

- Cyclist dapat menyiapkan rute, merekam ride dari start sampai finish, dan meninjau hasilnya **tanpa akun dan tanpa jaringan**, lalu sesi yang sama aman tersimpan setelah restart/force-stop pada perangkat sasaran.
- Cyclist dapat **merencanakan rute** dari peta (tidak hanya mengimpor GPX), melihat profil elevasi, dan mengikutinya dengan profil elevasi + progres, dengan fallback offline yang jelas.
- Cyclist dapat membagikan aktivitas ke **feed** dan menerima kudos; follow cyclist lain; bergabung dengan **klub/tim**; ikut **tantangan**; dan bertanding di **leaderboard segmen** dengan opt-in dan alias publik.
- **Segmen** (tanjakan/rute) dapat dibuat, dicocokkan dari ride, dan diberi peringkat, dengan leaderboard yang dihitung server-side dan tidak membocorkan identitas.
- Setiap angka progres/AI dapat **ditelusuri** ke sesi sumber; data hilang tetap "tidak diketahui", bukan nol.
- Seluruh tumpukan berjalan dalam **kuota gratis** pada skala proyek/tugas akhir, dengan jalur upgrade yang jelas dan dokumentasi verifikasi.

## 6. Ruang Lingkup Visi v1 (Go-Live)

**Termasuk:**

- Pilar 1 (Ride) matang: perekaman, pemulihan, riwayat, ringkasan, ekspor/impor GPX & JSON.
- Pilar 2 inti: peta OSM, impor GPX, **perencanaan rute + elevasi**, panduan; **segmen v1 (buat + cocokkan + leaderboard)**.
- Pilar 3 inti: dashboard progres, target, workout interval, AI analitik + LLM dengan consent.
- Pilar 4 inti: feed, follow, kudos, komentar, klub/tim, tantangan, berbagi.
- Identitas: custom email auth + biometrik; profil; zona privasi.
- Notifikasi lokal + push remote (FCM/APNs) opt-in.

**Ditunda (bukan v1):**

- Live tracking real-time (teman melihat posisi langsung).
- Marketplace / rute berbayar.
- Integrasi wearable penuh (Garmin) sampai approval partner; v1 memakai impor file + Health Connect/HealthKit.
- Blockchain publik sungguhan (tetap ledger hash jujur, dilihat [tech-stack.md](tech-stack.md)).
- Multi-sport (renang, lari) di luar sepeda.

## 7. Model Biaya: "Gratis Dulu, Bayar Hanya Bila Terbukti"

Visi ini harus **dapat dijalankan tanpa biaya langganan** selama fase tugas akhir/validasi:

- Database, auth, storage, edge functions: **Supabase Free**.
- Peta, geocoding, routing, elevasi, cuaca, kurs: provider **gratis/OSS tanpa API key** sebisa mungkin (OpenFreeMap, Photon, BRouter/Valhalla, Open-Meteo, Frankfurter).
- AI/LLM: **free tier** Gemini/Groq/OpenRouter, dengan Ollama lokal untuk pengembangan.
- Push: **FCM/APNs** (gratis) melalui Edge Function.
- Media: Supabase Storage free; opsi Cloudflare R2 untuk egress gratis.

Rincian, batas, fallback, dan status verifikasi ada di [tech-stack.md](tech-stack.md). Setiap provider berbayar yang dipilih wajib dicatat sebagai keputusan PO dengan mitigasi biaya.

## 8. Pengukuran Keberhasilan

Selaras dengan [scrum-guide.md](scrum-guide.md) Bagian 9:

- **Ride tidak kehilangan data** — % skenario lifecycle yang memulihkan seluruh sampel ter-acknowledge lokal.
- **Ringkasan dapat dipercaya** — % metrik deterministik yang sama dengan hitung ulang fixture sumber.
- **Alur inti offline-first** — semua skenario persiapan/rekam/review berjalan tanpa jaringan.
- **Keterlibatan sosial** — % pengguna mingguan yang membuka feed/segmen/klub.
- **Privasi** — nol temuan high-risk; nol data lokasi/pesan sensitif pada log.
- **Biaya** — biaya provider per pengguna aktif tetap di dalam kuota gratis pada baseline yang disepakati.

---

*Dokumen ini adalah komitmen arah. Perubahan visi harus melalui keputusan PO dan diperbarui di semua dokumen turunan pada increment yang sama.*
