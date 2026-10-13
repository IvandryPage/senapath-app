String formatCoachRecommendation(String recommendation, {int maxWords = 14}) {
  final firstLine = recommendation
      .replaceAll(RegExp(r'```[^`]*```', dotAll: true), ' ')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '')
      .replaceAll(RegExp(r'[*_`#]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (firstLine.isEmpty) return '';

  final firstSentence = firstLine
      .replaceFirst(RegExp(r'^(?:[-•*]|\d+[.)])\s*'), '')
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .first
      .trim();
  final words = firstSentence.split(' ');
  if (words.length <= maxWords) return firstSentence;
  return '${words.take(maxWords).join(' ')}…';
}
