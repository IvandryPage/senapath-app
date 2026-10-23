import 'dart:convert';

import 'package:http/http.dart' as http;

/// Transaksi EVM hasil pembacaan RPC.
class EvmTransaction {
  /// Membuat data transaksi EVM.
  const EvmTransaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.input,
    this.blockNumber,
  });

  final String hash;
  final String from;
  final String? to;

  /// Calldata transaksi dalam hex ber-prefiks `0x`.
  final String input;
  final int? blockNumber;
}

/// Receipt transaksi EVM hasil pembacaan RPC.
class EvmReceipt {
  /// Membuat data receipt EVM.
  const EvmReceipt({required this.succeeded, required this.blockNumber});

  final bool succeeded;
  final int blockNumber;
}

/// Pengecualian saat panggilan RPC EVM gagal.
class EvmRpcException implements Exception {
  /// Membuat pengecualian RPC EVM.
  const EvmRpcException(this.message);
  final String message;
  /// Mengembalikan pesan error sebagai teks.
  @override
  String toString() => message;
}

/// Klien JSON-RPC minimal (eth_getTransactionByHash / eth_getTransactionReceipt
/// / eth_chainId) untuk membaca data langsung dari node blockchain.
class EvmRpcClient {
  /// Membuat klien RPC EVM.
  EvmRpcClient(this.rpcUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final String rpcUrl;
  final http.Client _client;
  int _nextId = 1;

  /// Mengambil ID rantai blockchain.
  Future<int> chainId() async =>
      _parseHexInt(await _call('eth_chainId', const []))!;

  /// Mengambil data transaksi berdasarkan hash.
  Future<EvmTransaction?> getTransaction(String txHash) async {
    final result = await _call('eth_getTransactionByHash', [txHash]);
    if (result == null) return null;
    if (result is! Map) throw const EvmRpcException('Respons RPC tidak valid.');
    return EvmTransaction(
      hash: result['hash'] as String,
      from: result['from'] as String,
      to: result['to'] as String?,
      input: (result['input'] ?? result['data']) as String,
      blockNumber: _parseHexInt(result['blockNumber']),
    );
  }

  /// Mengambil receipt transaksi berdasarkan hash.
  Future<EvmReceipt?> getReceipt(String txHash) async {
    final result = await _call('eth_getTransactionReceipt', [txHash]);
    if (result == null) return null;
    if (result is! Map) throw const EvmRpcException('Respons RPC tidak valid.');
    return EvmReceipt(
      succeeded: _parseHexInt(result['status']) == 1,
      blockNumber: _parseHexInt(result['blockNumber']) ?? 0,
    );
  }

  /// Melakukan panggilan JSON-RPC.
  Future<Object?> _call(String method, List<Object?> params) async {
    final response = await _client
        .post(
          Uri.parse(rpcUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': _nextId++,
            'method': method,
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EvmRpcException(
        'RPC blockchain gagal (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const EvmRpcException('Respons RPC tidak valid.');
    }
    if (decoded['error'] != null) {
      final error = decoded['error'];
      throw EvmRpcException(
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'RPC mengembalikan error.',
      );
    }
    return decoded['result'];
  }

  /// Mengonversi nilai hex berawalan 0x menjadi int.
  static int? _parseHexInt(Object? value) {
    if (value is! String || !value.startsWith('0x')) return null;
    return int.tryParse(value.substring(2), radix: 16);
  }

  /// Menutup klien HTTP.
  void close() => _client.close();
}
