class RideLedgerBlock {
  const RideLedgerBlock({
    required this.index,
    required this.sessionId,
    required this.createdAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.previousHash,
    required this.hash,
  });

  final int index;
  final String sessionId;
  final DateTime createdAt;
  final double distanceMeters;
  final int durationSeconds;
  final String previousHash;
  final String hash;

  Map<String, Object?> toJson() => {
    'index': index,
    'sessionId': sessionId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'previousHash': previousHash,
    'hash': hash,
  };

  factory RideLedgerBlock.fromJson(Map<String, dynamic> json) =>
      RideLedgerBlock(
        index: json['index'] as int,
        sessionId: json['sessionId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        durationSeconds: json['durationSeconds'] as int,
        previousHash: json['previousHash'] as String,
        hash: json['hash'] as String,
      );
}
