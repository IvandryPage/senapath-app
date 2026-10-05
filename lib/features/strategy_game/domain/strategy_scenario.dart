class StrategyOption {
  const StrategyOption({required this.text, required this.explanation});

  final String text;
  final String explanation;
}

class StrategyScenario {
  const StrategyScenario({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.options,
    required this.recommendedOption,
    required this.takeaway,
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final List<StrategyOption> options;
  final int recommendedOption;
  final String takeaway;
}

const strategyScenarios = <StrategyScenario>[
  StrategyScenario(
    id: 'climb-pacing',
    category: 'Pacing',
    title: 'Tanjakan di tengah rute',
    description:
        'Profil rute menunjukkan tanjakan panjang setelah bagian datar. '
        'Bagaimana kamu menyusun strategi tenaga untuk simulasi ini?',
    options: [
      StrategyOption(
        text: 'Mengeluarkan tenaga maksimal sejak bagian datar.',
        explanation:
            'Awal yang terlalu agresif dapat mengurangi pilihan strategi '
            'untuk segmen berikutnya.',
      ),
      StrategyOption(
        text: 'Menjaga tempo terukur dan menyisakan ruang untuk menyesuaikan '
            'usaha di tanjakan.',
        explanation:
            'Tempo yang terencana memberi ruang untuk merespons perubahan '
            'profil rute.',
      ),
      StrategyOption(
        text: 'Mengubah tempo setiap kali peserta lain mempercepat.',
        explanation:
            'Bereaksi pada setiap perubahan dapat membuat rencana awal '
            'kehilangan konsistensi.',
      ),
    ],
    recommendedOption: 1,
    takeaway:
        'Pertimbangkan profil rute saat membagi usaha; simulasi ini bukan '
        'resep intensitas latihan.',
  ),
  StrategyScenario(
    id: 'group-surge',
    category: 'Membaca situasi',
    title: 'Kelompok mempercepat tempo',
    description:
        'Dalam simulasi balap, kelompok bergerak lebih cepat menjelang '
        'segmen panjang. Apa respons strategis yang paling terukur?',
    options: [
      StrategyOption(
        text: 'Langsung mengikuti semua percepatan tanpa melihat rencana.',
        explanation:
            'Perubahan spontan dapat membuat strategi sulit dievaluasi.',
      ),
      StrategyOption(
        text: 'Membandingkan situasi dengan rencana dan memilih respons yang '
            'masih sesuai tujuan.',
        explanation:
            'Mengacu kembali pada tujuan membantu memilih kapan perlu '
            'menyesuaikan strategi.',
      ),
      StrategyOption(
        text: 'Mengabaikan seluruh informasi dari kelompok.',
        explanation:
            'Informasi sekitar dapat menjadi salah satu konteks, meski '
            'bukan satu-satunya dasar keputusan.',
      ),
    ],
    recommendedOption: 1,
    takeaway:
        'Gunakan konteks untuk menilai opsi, bukan sebagai perintah otomatis.',
  ),
  StrategyScenario(
    id: 'route-checkpoint',
    category: 'Perencanaan rute',
    title: 'Memilih di antara dua rencana',
    description:
        'Dua rute latihan punya jarak serupa: satu memiliki elevasi lebih '
        'berubah-ubah, satu lagi lebih konsisten. Apa langkah perencanaan '
        'yang paling informatif?',
    options: [
      StrategyOption(
        text: 'Memilih hanya dari nama rute.',
        explanation:
            'Nama rute tidak cukup untuk membandingkan karakteristiknya.',
      ),
      StrategyOption(
        text: 'Membandingkan profil, jarak, dan tujuan latihan sebelum '
            'memilih.',
        explanation:
            'Membandingkan data yang relevan membuat alasan pemilihan rute '
            'lebih jelas.',
      ),
      StrategyOption(
        text: 'Menganggap rute dengan elevasi tertinggi selalu terbaik.',
        explanation:
            'Tidak ada satu karakteristik yang selalu cocok untuk setiap '
            'tujuan latihan.',
      ),
    ],
    recommendedOption: 1,
    takeaway:
        'Cocokkan pilihan rute dengan tujuan; skenario ini tidak menilai '
        'kemampuan fisik.',
  ),
];
