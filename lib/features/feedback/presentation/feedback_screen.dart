import 'package:flutter/material.dart';

import '../../../app/theme/senapath_design.dart';

class FeedbackScreen extends StatelessWidget {
  /// Membuat layar saran dan kesan dengan key opsional.
  const FeedbackScreen({super.key});

  @override
  /// Membangun daftar berisi judul, saran, dan kesan mata kuliah.
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Text('Saran dan Kesan', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        'Mata Kuliah Pemrograman Aplikasi Mobile.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      const _FeedbackNoteCard(
        icon: Icons.lightbulb_outline,
        title: 'Saran',
        message:
            'Saya menyarankan agar requirements proyek dibuat lebih fleksibel dan disesuaikan dengan relevansi tema aplikasi. Permintaan yang terlalu banyak dan juga spesifik dapat membatasi kreatifitas mahasiswa dalam mengimplementasikan proyek mobile. Saya menyarankan juga untuk kolaborasi dengan mata kuliah Desain Pengalaman Pengguna sehingga aplikasi yang dibuat dapat benar-benar menyelesaikan suatu permasalahan nyata, bukan hanya pemenuhan requirements.'
      ),
      const SizedBox(height: 12),
      const _FeedbackNoteCard(
        icon: Icons.favorite_outline,
        title: 'Kesan',
        message:
            'Mata kuliah ini memberikan pengalaman yang menantang dan bermanfaat karena mendorong mahasiswa untuk mengintegrasikan berbagai teknologi ke dalam satu aplikasi yang utuh. Mahasiswa tidak hanya dituntut untuk membangun antarmuka, tetapi juga memahami autentikasi, pengelolaan basis data, integrasi API, sensor perangkat, kecerdasan buatan, dan aspek keamanan sistem. Melalui proyek ini, saya dapat memperoleh gambaran yang lebih nyata mengenai kompleksitas pengembangan aplikasi mobile serta pentingnya menghubungkan berbagai komponen agar dapat bekerja secara terpadu.'
      ),
    ],
  );
}

class _FeedbackNoteCard extends StatelessWidget {
  /// Membuat kartu catatan dengan ikon, judul, dan isi pesan.
  const _FeedbackNoteCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  /// Membangun kartu catatan berisi ikon, judul, dan teks pesan.
  Widget build(BuildContext context) => SenapathCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
