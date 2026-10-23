/// Referensi transaksi blockchain untuk head hash ledger bukti perjalanan.
class RideLedgerAnchor {
  /// Membuat referensi anchor blockchain.
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

  /// Menentukan apakah anchor telah terkonfirmasi.
  bool get isConfirmed => status == 'confirmed';

  /// Muatan yang harus ada di calldata transaksi.
  String get expectedPayload => 'senapath:v1:$blockCount:$headHash';

  /// Membuat anchor dari data JSON.
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

/// Informasi jaringan blockchain untuk pencatatan bukti.
class RideLedgerChainInfo {
  /// Membuat informasi jaringan blockchain.
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

  /// Membentuk URL transaksi di explorer blockchain.
  Uri txUrl(String txHash) => Uri.parse('$explorerUrl/tx/$txHash');

  /// Membuat informasi jaringan dari data JSON.
  factory RideLedgerChainInfo.fromJson(Map<String, dynamic> json) =>
      RideLedgerChainInfo(
        chainId: (json['chainId'] as num).toInt(),
        name: json['name'] as String,
        explorerUrl: json['explorerUrl'] as String,
        publicRpcUrl: json['publicRpcUrl'] as String,
        relayerAddress: json['relayerAddress'] as String,
      );
}

/// Daftar anchor beserta informasi jaringan blockchain.
class RideLedgerAnchorList {
  /// Membuat daftar anchor blockchain.
  const RideLedgerAnchorList({required this.chain, required this.anchors});

  final RideLedgerChainInfo chain;
  final List<RideLedgerAnchor> anchors;

  /// Membuat daftar anchor dari data JSON.
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

/// Hasil verifikasi anchor terhadap blockchain publik.
class AnchorVerification {
  /// Membuat hasil verifikasi anchor.
  const AnchorVerification(this.status, this.detail);

  final AnchorVerificationStatus status;
  final String detail;
}
