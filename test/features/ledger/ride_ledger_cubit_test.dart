import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ledger/data/ride_ledger_repository.dart';
import 'package:senapath/features/ledger/data/ride_ledger_sync_gateway.dart';
import 'package:senapath/features/ledger/domain/ride_ledger_anchor.dart';
import 'package:senapath/features/ledger/domain/ride_ledger_block.dart';
import 'package:senapath/features/ledger/presentation/ride_ledger_cubit.dart';
import 'package:senapath/features/session/domain/ride_session.dart';

import '../../helpers/test_database.dart';

const _chain = RideLedgerChainInfo(
  chainId: 11155111,
  name: 'Ethereum Sepolia (testnet)',
  explorerUrl: 'https://sepolia.etherscan.io',
  publicRpcUrl: 'https://rpc.example',
  relayerAddress: '0x00000000000000000000000000000000000000aa',
);

class FakeLedgerGateway implements RideLedgerSyncGateway {
  final calls = <String>[];
  List<RideLedgerAnchor> stored = [];

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => true;

  @override
  Future<RideLedgerSyncResult> sync(List<RideLedgerBlock> blocks) async {
    calls.add('sync');
    return RideLedgerSyncResult(
      blockCount: blocks.length,
      head: blocks.last.hash,
      message: 'ok',
    );
  }

  @override
  Future<RideLedgerAnchorList> anchor() async {
    calls.add('anchor');
    stored = [
      RideLedgerAnchor(
        id: 'a1',
        blockCount: 1,
        headHash: 'ab' * 32,
        txHash: '0x${'11' * 32}',
        status: 'submitted',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    return RideLedgerAnchorList(chain: _chain, anchors: stored);
  }

  @override
  Future<RideLedgerAnchorList> anchors() async =>
      RideLedgerAnchorList(chain: _chain, anchors: stored);
}

void main() {
  test('anchor syncs the ledger first, then records the chain head', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = RideLedgerRepository(database);
    await repository.appendSession(
      RideSessionSnapshot(
        id: 's1',
        startedAt: DateTime.utc(2026, 1, 5, 8),
        endedAt: DateTime.utc(2026, 1, 5, 9),
        status: RideSessionStatus.completed,
        totalPausedMilliseconds: 0,
        distanceMeters: 5000,
        currentSpeedMetersPerSecond: 0,
      ),
    );
    final gateway = FakeLedgerGateway();
    final cubit = RideLedgerCubit(repository, syncGateway: gateway);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.anchor();

    expect(gateway.calls, ['sync', 'anchor']);
    expect(cubit.state.anchors, hasLength(1));
    expect(cubit.state.chain?.chainId, 11155111);
    expect(cubit.state.isAnchoring, isFalse);
    expect(cubit.state.error, isNull);
    expect(cubit.state.isVerified, isTrue);
  });
}
