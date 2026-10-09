import { verifyAppAccessToken } from "../_shared/app_auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const jsonResponse = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

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
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse(503, { error: "Cloud proof belum dikonfigurasi." });
  }

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = await request.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return jsonResponse(400, { error: "Invalid request body." });
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return jsonResponse(400, { error: "Invalid JSON request body." });
  }
  if (body.consent !== true || !Array.isArray(body.blocks)) {
    return jsonResponse(400, {
      error: "Persetujuan dan blok bukti diperlukan.",
    });
  }
  if (body.blocks.length > 2000) {
    return jsonResponse(413, { error: "Maksimal 2000 blok per sinkronisasi." });
  }

  const response = await fetch(
    `${supabaseUrl}/rest/v1/rpc/append_my_ride_proof_blocks`,
    {
      method: "POST",
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_user_id: user.sub, p_blocks: body.blocks }),
      signal: AbortSignal.timeout(20000),
    },
  );
  if (!response.ok) {
    const detail = await response.text();
    console.error("Cloud proof append failed", {
      status: response.status,
      detail: detail.slice(0, 300),
    });
    return jsonResponse(409, {
      error: "Rantai lokal bertentangan dengan ledger cloud. Tidak ada blok yang diganti.",
    });
  }
  const rows: unknown = await response.json();
  if (!Array.isArray(rows) || !rows[0] || typeof rows[0] !== "object") {
    return jsonResponse(502, { error: "Respons cloud proof tidak valid." });
  }
  const chain = rows[0] as Record<string, unknown>;
  if (
    typeof chain.latest_hash !== "string" ||
    typeof chain.block_count !== "number"
  ) {
    return jsonResponse(502, { error: "Respons cloud proof tidak valid." });
  }
  return jsonResponse(200, {
    cloudSynced: true,
    blockCount: chain.block_count,
    head: chain.latest_hash,
    message: "Ledger bukti perjalanan berhasil disinkronkan ke database cloud.",
  });
});
