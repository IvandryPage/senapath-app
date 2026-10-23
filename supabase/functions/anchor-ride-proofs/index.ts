import { verifyAppAccessToken } from "../_shared/app_auth.ts";
import {
  buildAnchorPayload,
  createProvider,
  loadChainConfig,
  readReceipt,
  relayerAddress,
  sendAnchorTransaction,
} from "../_shared/chain_anchor.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const jsonResponse = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

interface AnchorRow {
  id: string;
  block_count: number;
  head_hash: string;
  chain_id: number;
  tx_hash: string | null;
  status: "pending" | "submitted" | "confirmed" | "failed";
  block_number: number | null;
  created_at: string;
}

const anchorJson = (row: AnchorRow) => ({
  id: row.id,
  blockCount: row.block_count,
  headHash: row.head_hash,
  txHash: row.tx_hash,
  status: row.status,
  blockNumber: row.block_number,
  createdAt: row.created_at,
});

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const user = await verifyAppAccessToken(request);
  if (!user) {
    return jsonResponse(401, {
      error: "Sesi akun tidak valid. Silakan masuk kembali.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const config = loadChainConfig();
  if (!supabaseUrl || !serviceKey || !config) {
    return jsonResponse(503, {
      error: "Anchor blockchain belum dikonfigurasi di server.",
    });
  }

  let body: Record<string, unknown> = {};
  try {
    const parsed: unknown = await request.json();
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      body = parsed as Record<string, unknown>;
    }
  } catch {
    return jsonResponse(400, { error: "Invalid JSON request body." });
  }
  const action = body.action;
  if (action !== "anchor" && action !== "list") {
    return jsonResponse(400, { error: "Aksi tidak dikenal." });
  }

  const rest = (path: string, init: RequestInit = {}) =>
    fetch(`${supabaseUrl}/rest/v1/${path}`, {
      ...init,
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
        ...(init.headers ?? {}),
      },
      signal: AbortSignal.timeout(20000),
    });
  const patch = (id: string, values: Record<string, unknown>) =>
    rest(`ride_proof_chain_anchors?id=eq.${id}`, {
      method: "PATCH",
      body: JSON.stringify({ ...values, updated_at: new Date().toISOString() }),
    });

  const chain = {
    chainId: config.chainId,
    name: config.name,
    explorerUrl: config.explorerUrl,
    publicRpcUrl: config.publicRpcUrl,
    relayerAddress: relayerAddress(config),
  };
  const provider = createProvider(config);

  try {
    if (action === "anchor") {
      if (body.consent !== true) {
        return jsonResponse(400, { error: "Persetujuan diperlukan." });
      }
      const reserve = await rest("rpc/reserve_ride_proof_anchor", {
        method: "POST",
        body: JSON.stringify({
          p_user_id: user.sub,
          p_chain_id: config.chainId,
        }),
      });
      if (!reserve.ok) {
        const detail = await reserve.text();
        if (detail.includes("NO_PROOFS")) {
          return jsonResponse(409, {
            error: "Sinkronkan bukti ke cloud terlebih dahulu.",
          });
        }
        if (detail.includes("RATE_LIMITED")) {
          return jsonResponse(429, {
            error: "Tunggu beberapa menit sebelum mencatat ke blockchain lagi.",
          });
        }
        console.error("Reserve anchor failed", detail.slice(0, 300));
        return jsonResponse(502, { error: "Reservasi anchor gagal." });
      }
      const reserved = (await reserve.json())?.[0];
      if (!reserved) {
        return jsonResponse(502, { error: "Respons anchor tidak valid." });
      }

      let txHash: string | null = reserved.tx_hash;
      if (!reserved.reused || !txHash) {
        const payload = buildAnchorPayload(
          Number(reserved.block_count),
          reserved.head_hash,
        );
        try {
          txHash = await sendAnchorTransaction(config, payload, provider);
        } catch (error) {
          const code = (error as { code?: string }).code ?? "UNKNOWN";
          console.error("Anchor transaction failed", {
            code,
            message: String((error as Error).message).slice(0, 300),
          });
          await patch(reserved.anchor_id, {
            status: "failed",
            error: code,
          });
          return jsonResponse(
            code === "INSUFFICIENT_FUNDS" ? 503 : 502,
            {
              error: code === "INSUFFICIENT_FUNDS"
                ? "Saldo relayer habis. Hubungi pengelola aplikasi."
                : "Transaksi blockchain gagal dikirim. Coba lagi nanti.",
            },
          );
        }
        await patch(reserved.anchor_id, {
          status: "submitted",
          tx_hash: txHash,
        });
      }
    }

    const list = await rest(
      `ride_proof_chain_anchors?user_id=eq.${user.sub}&chain_id=eq.${config.chainId}` +
        `&status=in.(submitted,confirmed)&order=created_at.desc&limit=20&select=*`,
    );
    if (!list.ok) {
      return jsonResponse(502, { error: "Daftar anchor tidak dapat dibaca." });
    }
    const rows = (await list.json()) as AnchorRow[];
    for (const row of rows) {
      if (row.status !== "submitted" || !row.tx_hash) continue;
      try {
        const receipt = await readReceipt(provider, row.tx_hash);
        if (receipt.state === "confirmed") {
          row.status = "confirmed";
          row.block_number = receipt.blockNumber;
          await patch(row.id, {
            status: "confirmed",
            block_number: receipt.blockNumber,
          });
        } else if (receipt.state === "failed") {
          await patch(row.id, { status: "failed", error: "reverted" });
          row.status = "failed";
        }
      } catch (error) {
        console.error("Receipt lookup failed", String(error).slice(0, 200));
      }
    }
    return jsonResponse(200, {
      chain,
      anchors: rows.filter((row) => row.status !== "failed").map(anchorJson),
    });
  } catch (error) {
    console.error("Anchor function error", String(error).slice(0, 300));
    return jsonResponse(502, { error: "Layanan blockchain tidak tersedia." });
  }
});
