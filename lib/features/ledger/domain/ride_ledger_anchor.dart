/// Referensi transaksi blockchain untuk head hash ledger bukti perjalanan.
class RideLedgerAnchor {
  const RideLedgerAnchor({
    required this.id,
    required this.blockCount,
    required this.headHash,
    required this.txHash,
    required this.status,
    required this.createdAt,
    this.blockNumber,
  });

  final String id;
  final int blockCount;
  final String headHash;
  final String? txHash;

  /// `submitted` atau `confirmed` (status menurut server relayer).
  final String status;
  final int? blockNumber;
  final DateTime createdAt;

  bool get isConfirmed => status == 'confirmed';

  /// Muatan yang harus ada di calldata transaksi.
  String get expectedPayload => 'senapath:v1:$blockCount:$headHash';

  factory RideLedgerAnchor.fromJson(Map<String, dynamic> json) =>
      RideLedgerAnchor(
        id: json['id'] as String,
        blockCount: (json['blockCount'] as num).toInt(),
        headHash: json['headHash'] as String,
        txHash: json['txHash'] as String?,
        status: json['status'] as String,
        blockNumber: (json['blockNumber'] as num?)?.toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      );
}

class RideLedgerChainInfo {
  const RideLedgerChainInfo({
    required this.chainId,
    required this.name,
    required this.explorerUrl,
    required this.publicRpcUrl,
    required this.relayerAddress,
  });

  final int chainId;
  final String name;
  final String explorerUrl;
  final String publicRpcUrl;
  final String relayerAddress;

  Uri txUrl(String txHash) => Uri.parse('$explorerUrl/tx/$txHash');

  factory RideLedgerChainInfo.fromJson(Map<String, dynamic> json) =>
      RideLedgerChainInfo(
        chainId: (json['chainId'] as num).toInt(),
        name: json['name'] as String,
        explorerUrl: json['explorerUrl'] as String,
        publicRpcUrl: json['publicRpcUrl'] as String,
        relayerAddress: json['relayerAddress'] as String,
      );
}

class RideLedgerAnchorList {
  const RideLedgerAnchorList({required this.chain, required this.anchors});

  final RideLedgerChainInfo chain;
  final List<RideLedgerAnchor> anchors;

  factory RideLedgerAnchorList.fromJson(Map<String, dynamic> json) =>
      RideLedgerAnchorList(
        chain: RideLedgerChainInfo.fromJson(
          json['chain'] as Map<String, dynamic>,
        ),
        anchors: [
          for (final item in json['anchors'] as List<dynamic>)
            RideLedgerAnchor.fromJson(item as Map<String, dynamic>),
        ],
      );
}

enum AnchorVerificationStatus {
  /// Transaksi ada di chain, sukses, dan isinya cocok dengan ledger lokal.
  verified,

  /// Transaksi belum masuk blok.
  pending,

  /// Transaksi tidak ditemukan di RPC.
  notFound,

  /// Transaksi ada tetapi isi/pengirim/hash tidak cocok.
  mismatch,
}

class AnchorVerification {
  const AnchorVerification(this.status, this.detail);

  final AnchorVerificationStatus status;
  final String detail;
}
