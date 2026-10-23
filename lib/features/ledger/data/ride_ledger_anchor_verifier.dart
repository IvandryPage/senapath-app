import 'dart:convert';

import '../domain/ride_ledger_anchor.dart';
import '../domain/ride_ledger_block.dart';
import 'evm_rpc_client.dart';

/// Memverifikasi anchor tanpa mempercayai server Senapath: data dibaca
/// langsung dari node blockchain lewat JSON-RPC, lalu dicocokkan dengan
/// hash chain lokal di perangkat.
class RideLedgerAnchorVerifier {
  /// Membuat verifikator anchor blockchain.
  const RideLedgerAnchorVerifier();

  /// Memverifikasi anchor dengan membaca transaksi langsung dari RPC.
  Future<AnchorVerification> verify({
    required RideLedgerAnchor anchor,
    required RideLedgerChainInfo chain,
    required List<RideLedgerBlock> localBlocks,
    required EvmRpcClient rpc,
  }) async {
    final txHash = anchor.txHash;
    if (txHash == null) {
      return const AnchorVerification(
        AnchorVerificationStatus.notFound,
        'Anchor belum memiliki hash transaksi.',
      );
    }
    try {
      final remoteChainId = await rpc.chainId();
      if (remoteChainId != chain.chainId) {
        return AnchorVerification(
          AnchorVerificationStatus.mismatch,
          'RPC berada di chain $remoteChainId, seharusnya ${chain.chainId}.',
        );
      }
      final tx = await rpc.getTransaction(txHash);
      if (tx == null) {
        return const AnchorVerification(
          AnchorVerificationStatus.notFound,
          'Transaksi belum ditemukan di node RPC.',
        );
      }
      if (tx.blockNumber == null) {
        return const AnchorVerification(
          AnchorVerificationStatus.pending,
          'Transaksi menunggu masuk ke blok.',
        );
      }
      final receipt = await rpc.getReceipt(txHash);
      if (receipt == null) {
        return const AnchorVerification(
          AnchorVerificationStatus.pending,
          'Transaksi menunggu konfirmasi.',
        );
      }
      if (!receipt.succeeded) {
        return const AnchorVerification(
          AnchorVerificationStatus.mismatch,
          'Transaksi di-revert oleh jaringan.',
        );
      }
      if (tx.from.toLowerCase() != chain.relayerAddress.toLowerCase()) {
        return const AnchorVerification(
          AnchorVerificationStatus.mismatch,
          'Pengirim transaksi bukan relayer Senapath.',
        );
      }
      final onChain = _decodeInput(tx.input);
      if (onChain != anchor.expectedPayload) {
        return const AnchorVerification(
          AnchorVerificationStatus.mismatch,
          'Isi transaksi di blockchain tidak sama dengan catatan anchor.',
        );
      }
      final index = anchor.blockCount - 1;
      if (index >= localBlocks.length ||
          localBlocks[index].hash != anchor.headHash) {
        return const AnchorVerification(
          AnchorVerificationStatus.mismatch,
          'Hash di blockchain tidak cocok dengan ledger lokal.',
        );
      }
      return AnchorVerification(
        AnchorVerificationStatus.verified,
        'Cocok: bukti #${anchor.blockCount} ada di blok '
        '${receipt.blockNumber} ${chain.name}.',
      );
    } on EvmRpcException catch (error) {
      return AnchorVerification(
        AnchorVerificationStatus.notFound,
        error.message,
      );
    } catch (_) {
      return const AnchorVerification(
        AnchorVerificationStatus.notFound,
        'RPC blockchain tidak dapat dihubungi.',
      );
    }
  }

  /// Mendekode calldata hex menjadi string UTF-8.
  static String? _decodeInput(String hex) {
    if (!hex.startsWith('0x') || hex.length.isOdd) return null;
    try {
      final bytes = [
        for (var i = 2; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
