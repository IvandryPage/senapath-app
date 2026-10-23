import {
  getAddress,
  JsonRpcProvider,
  Network,
  toUtf8Bytes,
  toUtf8String,
  Wallet,
} from "npm:ethers@6.13.4";

export interface ChainConfig {
  chainId: number;
  name: string;
  explorerUrl: string;
  publicRpcUrl: string;
  rpcUrl: string;
  privateKey: string;
}

export const PAYLOAD_PREFIX = "senapath:v1";

/** Muatan on-chain: teks UTF-8 yang terbaca langsung di explorer (Input Data). */
export function buildAnchorPayload(blockCount: number, headHash: string) {
  if (!Number.isSafeInteger(blockCount) || blockCount < 1) {
    throw new Error("blockCount tidak valid.");
  }
  if (!/^[0-9a-f]{64}$/.test(headHash)) {
    throw new Error("headHash tidak valid.");
  }
  return `${PAYLOAD_PREFIX}:${blockCount}:${headHash}`;
}

export function parseAnchorPayload(hexData: string) {
  const text = toUtf8String(hexData);
  const match = text.match(/^senapath:v1:(\d+):([0-9a-f]{64})$/);
  if (!match) return null;
  return { blockCount: Number(match[1]), headHash: match[2] };
}

export function loadChainConfig(): ChainConfig | null {
  const rpcUrl = Deno.env.get("ANCHOR_RPC_URL");
  const privateKey = Deno.env.get("ANCHOR_PRIVATE_KEY");
  if (!rpcUrl || !privateKey) return null;
  const chainId = Number(Deno.env.get("ANCHOR_CHAIN_ID") ?? "11155111");
  if (!Number.isSafeInteger(chainId) || chainId < 1) return null;
  return {
    chainId,
    name: Deno.env.get("ANCHOR_CHAIN_NAME") ?? "Ethereum Sepolia (testnet)",
    explorerUrl: (Deno.env.get("ANCHOR_EXPLORER_URL") ??
      "https://sepolia.etherscan.io").replace(/\/+$/, ""),
    // RPC publik untuk verifikasi oleh app; jangan isi dengan URL berkunci API.
    publicRpcUrl: Deno.env.get("ANCHOR_PUBLIC_RPC_URL") ??
      "https://ethereum-sepolia-rpc.publicnode.com",
    rpcUrl,
    privateKey,
  };
}

export function createProvider(config: ChainConfig) {
  const network = Network.from(config.chainId);
  return new JsonRpcProvider(config.rpcUrl, network, {
    staticNetwork: network,
  });
}

export function relayerAddress(config: ChainConfig) {
  return getAddress(new Wallet(config.privateKey).address);
}

const RETRYABLE = ["NONCE_EXPIRED", "REPLACEMENT_UNDERPRICED"];

/**
 * Mengirim transaksi 0 nilai dari relayer ke dirinya sendiri dengan payload
 * sebagai calldata, lewat JSON-RPC (eth_sendRawTransaction). Mengulang bila
 * terjadi balapan nonce antar instance function.
 */
export async function sendAnchorTransaction(
  config: ChainConfig,
  payload: string,
  provider = createProvider(config),
) {
  const wallet = new Wallet(config.privateKey, provider);
  let lastError: unknown;
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const tx = await wallet.sendTransaction({
        to: wallet.address,
        value: 0,
        data: "0x" + [...toUtf8Bytes(payload)]
          .map((b) => b.toString(16).padStart(2, "0")).join(""),
      });
      return tx.hash;
    } catch (error) {
      lastError = error;
      const code = (error as { code?: string }).code ?? "";
      if (!RETRYABLE.includes(code)) throw error;
      await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
    }
  }
  throw lastError;
}

export type ReceiptState =
  | { state: "pending" }
  | { state: "confirmed"; blockNumber: number }
  | { state: "failed" };

export async function readReceipt(
  provider: JsonRpcProvider,
  txHash: string,
): Promise<ReceiptState> {
  const receipt = await provider.getTransactionReceipt(txHash);
  if (!receipt) return { state: "pending" };
  return receipt.status === 1
    ? { state: "confirmed", blockNumber: receipt.blockNumber }
    : { state: "failed" };
}
