class FeedbackSubmission {
  const FeedbackSubmission({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.consentedAt,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final DateTime consentedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'message': message,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'consentedAt': consentedAt.toUtc().toIso8601String(),
  };

  factory FeedbackSubmission.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final message = json['message'];
    final createdAt = json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String)
        : null;
    final consentedAt = json['consentedAt'] is String
        ? DateTime.tryParse(json['consentedAt'] as String)
        : null;
    if (id is! String ||
        id.isEmpty ||
        message is! String ||
        message.isEmpty ||
        message.length > 4000 ||
        createdAt == null ||
        consentedAt == null) {
      throw const FormatException('Invalid feedback submission.');
    }
    return FeedbackSubmission(
      id: id,
      message: message,
      createdAt: createdAt,
      consentedAt: consentedAt,
    );
  }
}
