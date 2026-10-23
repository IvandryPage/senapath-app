import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:senapath/features/ledger/data/evm_rpc_client.dart';
import 'package:senapath/features/ledger/data/ride_ledger_anchor_verifier.dart';
import 'package:senapath/features/ledger/domain/ride_ledger_anchor.dart';
import 'package:senapath/features/ledger/domain/ride_ledger_block.dart';

const _relayer = '0x00000000000000000000000000000000000000aa';
final _head = 'ab' * 32;
const _txHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

const _chain = RideLedgerChainInfo(
  chainId: 11155111,
  name: 'Ethereum Sepolia (testnet)',
  explorerUrl: 'https://sepolia.etherscan.io',
  publicRpcUrl: 'https://rpc.example',
  relayerAddress: _relayer,
);

RideLedgerAnchor _anchor() => RideLedgerAnchor(
  id: 'a1',
  blockCount: 1,
  headHash: _head,
  txHash: _txHash,
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 1, 1),
  blockNumber: 7,
);

List<RideLedgerBlock> _blocks({String? hash}) => [
  RideLedgerBlock(
    index: 0,
    sessionId: 's1',
    createdAt: DateTime.utc(2026, 1, 1),
    distanceMeters: 1000,
    durationSeconds: 60,
    previousHash: '0' * 64,
    hash: hash ?? _head,
  ),
];

String _hex(String text) =>
    '0x${utf8.encode(text).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

EvmRpcClient _rpc({
  int chainId = 11155111,
  Map<String, Object?>? tx,
  Map<String, Object?>? receipt,
}) => EvmRpcClient(
  'https://rpc.example',
  client: MockClient((http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final Object? result = switch (body['method']) {
      'eth_chainId' => '0x${chainId.toRadixString(16)}',
      'eth_getTransactionByHash' => tx,
      'eth_getTransactionReceipt' => receipt,
      _ => null,
    };
    return http.Response(
      jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      200,
    );
  }),
);

Map<String, Object?> _tx({String? input, String from = _relayer}) => {
  'hash': _txHash,
  'from': from,
  'to': from,
  'input': input ?? _hex('senapath:v1:1:$_head'),
  'blockNumber': '0x7',
};

const _okReceipt = {'status': '0x1', 'blockNumber': '0x7'};

Future<AnchorVerification> _verify(
  EvmRpcClient rpc, {
  List<RideLedgerBlock>? blocks,
}) => const RideLedgerAnchorVerifier().verify(
  anchor: _anchor(),
  chain: _chain,
  localBlocks: blocks ?? _blocks(),
  rpc: rpc,
);

void main() {
  group('RideLedgerAnchorVerifier', () {
    test('verifies a matching on-chain payload', () async {
      final result = await _verify(_rpc(tx: _tx(), receipt: _okReceipt));
      expect(result.status, AnchorVerificationStatus.verified);
    });

    test('reports not found when RPC has no transaction', () async {
      final result = await _verify(_rpc());
      expect(result.status, AnchorVerificationStatus.notFound);
    });

    test('reports pending while transaction is not mined', () async {
      final result = await _verify(_rpc(tx: {..._tx(), 'blockNumber': null}));
      expect(result.status, AnchorVerificationStatus.pending);
    });

    test('detects a different payload', () async {
      final result = await _verify(
        _rpc(
          tx: _tx(input: _hex('senapath:v1:1:${'cd' * 32}')),
          receipt: _okReceipt,
        ),
      );
      expect(result.status, AnchorVerificationStatus.mismatch);
    });

    test('detects an unexpected sender', () async {
      final result = await _verify(
        _rpc(
          tx: _tx(from: '0x00000000000000000000000000000000000000bb'),
          receipt: _okReceipt,
        ),
      );
      expect(result.status, AnchorVerificationStatus.mismatch);
    });

    test('detects a wrong chain id', () async {
      final result = await _verify(
        _rpc(chainId: 1, tx: _tx(), receipt: _okReceipt),
      );
      expect(result.status, AnchorVerificationStatus.mismatch);
    });

    test('detects a reverted transaction', () async {
      final result = await _verify(
        _rpc(tx: _tx(), receipt: {'status': '0x0', 'blockNumber': '0x7'}),
      );
      expect(result.status, AnchorVerificationStatus.mismatch);
    });

    test('detects local ledger that no longer matches the anchor', () async {
      final result = await _verify(
        _rpc(tx: _tx(), receipt: _okReceipt),
        blocks: _blocks(hash: 'cd' * 32),
      );
      expect(result.status, AnchorVerificationStatus.mismatch);
    });
  });
}
