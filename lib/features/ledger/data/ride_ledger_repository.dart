import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../../core/storage/app_database.dart';
import '../../session/domain/ride_session.dart';
import '../domain/ride_ledger_block.dart';

/// Repository penyimpanan dan verifikasi rantai bukti perjalanan.
class RideLedgerRepository {
  /// Membuat repository buku besar bukti perjalanan.
  RideLedgerRepository(this._database, {Sha256? digest})
    : _digest = digest ?? Sha256();

  static const _key = 'ride_proof_chain_v1';
  static final _genesisHash = List<String>.filled(64, '0').join();

  final AppDatabase _database;
  final Sha256 _digest;
  Future<void> _writeLock = Future<void>.value();

  /// Memuat daftar blok bukti dari penyimpanan lokal.
  Future<List<RideLedgerBlock>> loadBlocks() async {
    final row = await (_database.select(
      _database.appPreferences,
    )..where((item) => item.key.equals(_key))).getSingleOrNull();
    if (row == null) return const [];
    final decoded = jsonDecode(row.value);
    if (decoded is! List) {
      throw const FormatException('Data rantai bukti tidak valid.');
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>)
          RideLedgerBlock.fromJson(item)
        else
          throw const FormatException('Blok bukti tidak valid.'),
    ];
  }

  /// Menambahkan bukti dari sesi perjalanan yang selesai.
  Future<void> appendSession(RideSessionSnapshot session) async {
    final previousWrite = _writeLock;
    final completion = Completer<void>();
    _writeLock = completion.future;
    try {
      await previousWrite;
      if (session.status != RideSessionStatus.completed ||
          session.endedAt == null ||
          !session.distanceMeters.isFinite) {
        throw StateError('Hanya sesi selesai valid yang dapat diberi bukti.');
      }
      final blocks = await loadBlocks();
      if (blocks.any((block) => block.sessionId == session.id)) return;
      final previousHash = blocks.isEmpty ? _genesisHash : blocks.last.hash;
      final durationSeconds = session.durationAt(session.endedAt!).inSeconds;
      final canonical = jsonEncode({
        'index': blocks.length,
        'sessionId': session.id,
        'createdAt': session.endedAt!.toUtc().toIso8601String(),
        'distanceMeters': session.distanceMeters,
        'durationSeconds': durationSeconds,
        'previousHash': previousHash,
      });
      final hash = await _hash(canonical);
      final block = RideLedgerBlock(
        index: blocks.length,
        sessionId: session.id,
        createdAt: session.endedAt!,
        distanceMeters: session.distanceMeters,
        durationSeconds: durationSeconds,
        previousHash: previousHash,
        hash: hash,
      );
      await _save([...blocks, block]);
    } finally {
      completion.complete();
    }
  }

  /// Memverifikasi integritas rantai bukti lokal.
  Future<bool> verify() async {
    final blocks = await loadBlocks();
    var expectedPreviousHash = _genesisHash;
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (block.index != index ||
          block.previousHash != expectedPreviousHash ||
          !block.distanceMeters.isFinite ||
          block.distanceMeters < 0 ||
          block.durationSeconds < 0) {
        return false;
      }
      final canonical = jsonEncode({
        'index': block.index,
        'sessionId': block.sessionId,
        'createdAt': block.createdAt.toUtc().toIso8601String(),
        'distanceMeters': block.distanceMeters,
        'durationSeconds': block.durationSeconds,
        'previousHash': block.previousHash,
      });
      final expectedHash = await _hash(canonical);
      if (block.hash != expectedHash) return false;
      expectedPreviousHash = block.hash;
    }
    return true;
  }

  /// Menyimpan daftar blok ke penyimpanan lokal.
  Future<void> _save(List<RideLedgerBlock> blocks) async {
    await _database
        .into(_database.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _key,
            value: jsonEncode(blocks.map((block) => block.toJson()).toList()),
          ),
        );
  }

  /// Menghitung hash SHA-256 dalam format hex.
  Future<String> _hash(String value) async {
    final digest = await _digest.hash(utf8.encode(value));
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
