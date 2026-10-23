final _leadingMarker = RegExp(r'^(?:[-•*]|\d+[.)])\s*');
final _greeting = RegExp(
  r'^(?:halo|hallo|helo|hai|hi|hey|selamat\s+(?:pagi|siang|sore|malam)|'
  r'salam\s+[a-z]+|assalamualaikum(?:\s+warahmatullahi\s+wabarakatuh)?)'
  r'[\s,!.]*',
  caseSensitive: false,
);

/// Membersihkan penanda, sapaan, dan spasi berlebih dari teks rekomendasi.
String formatCoachRecommendation(String recommendation) {
  return recommendation
      .replaceAll(RegExp(r'```[^`]*```', dotAll: true), ' ')
      .replaceAll(RegExp(r'[*_`#]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(_leadingMarker, '')
      .replaceFirst(_greeting, '')
      .replaceFirst(_leadingMarker, '')
      .trim();
}
