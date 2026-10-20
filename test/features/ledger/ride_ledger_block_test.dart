import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ledger/domain/ride_ledger_block.dart';

void main() {
  group('RideLedgerBlock JSON', () {
    test('round-trips through JSON as UTC', () {
      final block = RideLedgerBlock(
        index: 3,
        sessionId: 's3',
        createdAt: DateTime.utc(2026, 1, 5, 12, 30),
        distanceMeters: 42000,
        durationSeconds: 5400,
        previousHash: 'a' * 64,
        hash: 'b' * 64,
      );

      final restored = RideLedgerBlock.fromJson(block.toJson());
      expect(restored.index, 3);
      expect(restored.sessionId, 's3');
      expect(restored.createdAt, DateTime.utc(2026, 1, 5, 12, 30));
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.distanceMeters, 42000);
      expect(restored.durationSeconds, 5400);
      expect(restored.previousHash, 'a' * 64);
      expect(restored.hash, 'b' * 64);
    });
  });
}
