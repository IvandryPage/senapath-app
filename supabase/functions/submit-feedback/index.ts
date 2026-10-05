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

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(503, { error: "Feedback service is not configured." });
  }

  try {
    const user = await verifyAppAccessToken(request);
    if (!user) {
      return jsonResponse(401, { error: "Authentication is required." });
    }

    const body = await request.json();
    const submissionId = body?.submissionId;
    const message = body?.message;
    if (
      body?.consent !== true ||
      typeof submissionId !== "string" ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(submissionId) ||
      typeof message !== "string" ||
      message.trim().length === 0 ||
      message.length > 4000
    ) {
      return jsonResponse(400, { error: "Invalid or unconsented feedback." });
    }

    const insertResponse = await fetch(`${supabaseUrl}/rest/v1/user_feedback`, {
      method: "POST",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
        Prefer: "resolution=ignore-duplicates,return=minimal",
      },
      body: JSON.stringify({
        idempotency_key: submissionId,
        user_id: user.sub,
        message: message.trim(),
        consented_at: new Date().toISOString(),
      }),
    });
    if (!insertResponse.ok) {
      return jsonResponse(503, { error: "Feedback could not be stored." });
    }
    return jsonResponse(200, { received: true });
  } catch {
    return jsonResponse(502, { error: "Feedback submission failed." });
  }
});
