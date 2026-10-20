import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/features/ledger/data/ride_ledger_repository.dart';
import 'package:senapath/features/ledger/domain/ride_ledger_block.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

import '../../helpers/test_database.dart';

RideSessionSnapshot _session({
  required String id,
  RideSessionStatus status = RideSessionStatus.completed,
  DateTime? endedAt,
  double distanceMeters = 5000,
}) => RideSessionSnapshot(
  id: id,
  startedAt: DateTime.utc(2026, 1, 5, 8),
  endedAt: endedAt ?? DateTime.utc(2026, 1, 5, 9),
  status: status,
  totalPausedMilliseconds: 0,
  distanceMeters: distanceMeters,
  currentSpeedMetersPerSecond: 0,
);

void main() {
  group('RideLedgerRepository', () {
    test('starts with an empty chain', () async {
      final repository = RideLedgerRepository(createTestDatabase());
      expect(await repository.loadBlocks(), isEmpty);
      expect(await repository.verify(), isTrue);
    });

    test('appends completed sessions as a hash-linked chain', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = RideLedgerRepository(database);

      await repository.appendSession(_session(id: 's1'));
      await repository.appendSession(_session(id: 's2', distanceMeters: 8000));

      final blocks = await repository.loadBlocks();
      expect(blocks, hasLength(2));
      expect(blocks[0].index, 0);
      expect(blocks[1].index, 1);
      expect(blocks[1].previousHash, blocks[0].hash);
      expect(blocks.map((block) => block.sessionId), ['s1', 's2']);
      expect(blocks[1].distanceMeters, 8000);
      expect(blocks[0].durationSeconds, 3600);
      expect(await repository.verify(), isTrue);
    });

    test('ignores duplicate sessions', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = RideLedgerRepository(database);

      await repository.appendSession(_session(id: 's1'));
      await repository.appendSession(_session(id: 's1'));

      expect(await repository.loadBlocks(), hasLength(1));
    });

    test('rejects sessions that are not completed', () async {
      final repository = RideLedgerRepository(createTestDatabase());
      await expectLater(
        repository.appendSession(
          _session(id: 's1', status: RideSessionStatus.recording),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.appendSession(
          RideSessionSnapshot(
            id: 's1',
            startedAt: DateTime.utc(2026, 1, 5, 8),
            status: RideSessionStatus.completed,
            totalPausedMilliseconds: 0,
            distanceMeters: 5000,
            currentSpeedMetersPerSecond: 0,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('detects tampered blocks', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = RideLedgerRepository(database);
      await repository.appendSession(_session(id: 's1'));

      final blocks = await repository.loadBlocks();
      final tampered = RideLedgerBlock(
        index: blocks.single.index,
        sessionId: blocks.single.sessionId,
        createdAt: blocks.single.createdAt,
        distanceMeters: blocks.single.distanceMeters + 1000,
        durationSeconds: blocks.single.durationSeconds,
        previousHash: blocks.single.previousHash,
        hash: blocks.single.hash,
      );
      await database
          .into(database.appPreferences)
          .insertOnConflictUpdate(
            AppPreferencesCompanion.insert(
              key: 'ride_proof_chain_v1',
              value: jsonEncode([tampered.toJson()]),
            ),
          );

      expect(await repository.verify(), isFalse);
    });

    test('rejects a corrupted stored chain', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database
          .into(database.appPreferences)
          .insert(
            AppPreferencesCompanion.insert(
              key: 'ride_proof_chain_v1',
              value: '{"not": "a list"}',
            ),
          );

      final repository = RideLedgerRepository(database);
      expect(repository.loadBlocks, throwsFormatException);
    });

    test('rejects invalid entries inside the stored chain', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database
          .into(database.appPreferences)
          .insert(
            AppPreferencesCompanion.insert(
              key: 'ride_proof_chain_v1',
              value: '[42]',
            ),
          );

      final repository = RideLedgerRepository(database);
      expect(repository.loadBlocks, throwsFormatException);
    });
  });
}
