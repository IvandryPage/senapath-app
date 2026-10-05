class StrategyGameAnswer {
  const StrategyGameAnswer({
    required this.scenarioId,
    required this.category,
    required this.selectedOption,
    required this.wasRecommended,
  });

  final String scenarioId;
  final String category;
  final int selectedOption;
  final bool wasRecommended;

  Map<String, Object?> toJson() => {
    'scenarioId': scenarioId,
    'category': category,
    'selectedOption': selectedOption,
    'wasRecommended': wasRecommended,
  };

  factory StrategyGameAnswer.fromJson(Map<String, Object?> json) {
    final scenarioId = json['scenarioId'];
    final category = json['category'];
    final selectedOption = json['selectedOption'];
    final wasRecommended = json['wasRecommended'];
    if (scenarioId is! String ||
        category is! String ||
        selectedOption is! num ||
        wasRecommended is! bool) {
      throw const FormatException('Hasil tantangan strategi tidak valid.');
    }
    return StrategyGameAnswer(
      scenarioId: scenarioId,
      category: category,
      selectedOption: selectedOption.toInt(),
      wasRecommended: wasRecommended,
    );
  }
}

class StrategyGameResult {
  const StrategyGameResult({
    required this.id,
    required this.playedAt,
    required this.answers,
    required this.scenarioCount,
  });

  final String id;
  final DateTime playedAt;
  final List<StrategyGameAnswer> answers;
  final int scenarioCount;

  int get score => answers.where((answer) => answer.wasRecommended).length;

  Map<String, Object?> toJson() => {
    'id': id,
    'playedAt': playedAt.toUtc().toIso8601String(),
    'scenarioCount': scenarioCount,
    'answers': answers.map((answer) => answer.toJson()).toList(),
  };

  factory StrategyGameResult.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final playedAt = json['playedAt'];
    final scenarioCount = json['scenarioCount'];
    final rawAnswers = json['answers'];
    final parsedPlayedAt = playedAt is String
        ? DateTime.tryParse(playedAt)
        : null;
    if (id is! String ||
        parsedPlayedAt == null ||
        scenarioCount is! num ||
        scenarioCount < 1 ||
        rawAnswers is! List) {
      throw const FormatException('Hasil tantangan strategi tidak valid.');
    }
    return StrategyGameResult(
      id: id,
      playedAt: parsedPlayedAt.toUtc(),
      scenarioCount: scenarioCount.toInt(),
      answers: [
        for (final rawAnswer in rawAnswers)
          if (rawAnswer is Map)
            StrategyGameAnswer.fromJson(Map<String, Object?>.from(rawAnswer))
          else
            throw const FormatException('Jawaban tantangan tidak valid.'),
      ],
    );
  }
}
