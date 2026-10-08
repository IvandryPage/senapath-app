import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT } from "npm:jose@5.10.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const accessTokenLifetimeSeconds = 10 * 60;
const refreshTokenLifetimeSeconds = 30 * 24 * 60 * 60;
const passwordIterations = 210_000;
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const jwtSecret = Deno.env.get("APP_AUTH_JWT_SECRET");
const supabase = supabaseUrl && serviceRoleKey
  ? createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  : null;

type AuthAction =
  | "register"
  | "sign-in"
  | "refresh"
  | "sign-out"
  | "password-reset-request"
  | "password-reset-complete";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }
  if (!supabase) {
    return jsonResponse({
      error:
        "Auth server needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY configured for this Edge Function.",
    }, 503);
  }
  if (!jwtSecret || jwtSecret.length < 32) {
    return jsonResponse({
      error:
        "Auth server is missing APP_AUTH_JWT_SECRET. Add a 32+ character signing secret to Supabase Edge Function secrets and ensure Supabase API trusts the same signing key.",
    }, 503);
  }

  const requestId = crypto.randomUUID();
  try {
    const input = await request.json();
    if (!isRecord(input) || typeof input.action !== "string") {
      return jsonResponse({ error: "Invalid request." }, 400);
    }
    const action = input.action as AuthAction;
    if (
      action === "password-reset-request" &&
      !passwordRecoveryConfigured()
    ) {
      return jsonResponse({
        error:
          "Password recovery needs RESEND_API_KEY, AUTH_EMAIL_FROM, and AUTH_PASSWORD_RESET_URL in Supabase Edge Function secrets.",
      }, 503);
    }
    if (["register", "sign-in", "password-reset-request"].includes(action)) {
      const email = normalizeEmail(input.email);
      if (email) {
        const clientIp = request.headers.get("cf-connecting-ip") ??
          request.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
          "unknown";
        const limits = action === "password-reset-request"
          ? { email: 3, ip: 20 }
          : { email: 5, ip: 30 };
        const [emailAllowed, ipAllowed] = await Promise.all([
          consumeRateLimit(`email:${email}:${clientIp}`, limits.email),
          consumeRateLimit(`ip:${clientIp}`, limits.ip),
        ]);
        if (!emailAllowed || !ipAllowed) {
          return jsonResponse(
            { error: "Too many attempts. Wait before trying again." },
            429,
          );
        }
      }
    }
    switch (action) {
      case "register":
        return await register(input);
      case "sign-in":
        return await signIn(input);
      case "refresh":
        return await refreshSession(input);
      case "sign-out":
        return await signOut(input);
      case "password-reset-request":
        return await requestPasswordReset(input);
      case "password-reset-complete":
        return await completePasswordReset(input);
      default:
        return jsonResponse({ error: "Unsupported auth action." }, 400);
    }
  } catch (error) {
    const code = getErrorCode(error);
    console.error("app-auth request failed", { requestId, code, error });
    if (
      code &&
      [
        "42P01",
        "42703",
        "42883",
        "PGRST202",
        "PGRST204",
        "PGRST205",
      ].includes(code)
    ) {
      return jsonResponse({
        error:
          "Auth database schema is incomplete. Apply the Supabase migrations with `supabase db push`, then redeploy app-auth.",
        requestId,
      }, 503);
    }
    return jsonResponse({
      error:
        `Authentication request failed. Check app-auth logs (reference ${requestId}).`,
    }, 500);
  }
});

async function register(input: Record<string, unknown>): Promise<Response> {
  const email = normalizeEmail(input.email);
  const password = input.password;
  if (
    !email ||
    typeof password !== "string" ||
    password.length < 8 ||
    password.length > 128
  ) {
    return jsonResponse(
      { error: "Enter a valid email and a password of at least 8 characters." },
      400,
    );
  }
  const { data: existing, error: lookupError } = await supabase!.from(
    "app_users",
  ).select("id, password_hash").eq("email", email).maybeSingle();
  if (lookupError) throw lookupError;
  if (existing) {
    return jsonResponse({
      error: existing.password_hash === null
        ? "This email belongs to an existing account without a custom password. It cannot be claimed without proving ownership."
        : "An account with this email already exists. Sign in instead.",
    }, 409);
  }
  const refreshToken = randomToken();
  const { data, error } = await supabase!.rpc("register_app_user", {
    p_email: email,
    p_password_hash: await hashPassword(password),
    p_refresh_token_hash: await sha256(refreshToken),
    p_expires_at: new Date(
      Date.now() + refreshTokenLifetimeSeconds * 1000,
    ).toISOString(),
  }).single();
  if (error) {
    if (error.code === "23505") {
      return jsonResponse({
        error: "An account with this email already exists. Sign in instead.",
      }, 409);
    }
    throw error;
  }
  if (
    !isRecord(data) ||
    typeof data.account_id !== "string" ||
    typeof data.account_email !== "string"
  ) {
    throw new Error("Account creation returned no user.");
  }
  return jsonResponse(
    await createSession(data.account_id, data.account_email, refreshToken),
    201,
  );
}

async function signIn(input: Record<string, unknown>): Promise<Response> {
  const email = normalizeEmail(input.email);
  const password = input.password;
  if (!email || typeof password !== "string" || password.length > 128) {
    return jsonResponse({ error: "Invalid email or password." }, 400);
  }
  const { data: user, error } = await supabase!.from("app_users")
    .select("id, email, password_hash")
    .eq("email", email)
    .maybeSingle();
  if (error) throw error;
  let valid = false;
  if (typeof user?.password_hash === "string") {
    valid = await verifyPassword(password, user.password_hash);
  } else {
    await hashPassword(password);
  }
  if (!user || !valid) {
    return jsonResponse({ error: "Invalid email or password." }, 401);
  }
  return jsonResponse(await createSession(user.id, user.email));
}

async function refreshSession(
  input: Record<string, unknown>,
): Promise<Response> {
  if (
    typeof input.refreshToken !== "string" ||
    input.refreshToken.length > 200
  ) {
    return jsonResponse({ error: "Session refresh is invalid." }, 401);
  }
  const newRefreshToken = randomToken();
  const newExpiresAt = new Date(
    Date.now() + refreshTokenLifetimeSeconds * 1000,
  ).toISOString();
  const { data, error } = await supabase!.rpc("rotate_app_auth_session", {
    p_old_token_hash: await sha256(input.refreshToken),
    p_new_token_hash: await sha256(newRefreshToken),
    p_expires_at: newExpiresAt,
  });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : null;
  if (!row || typeof row.user_id !== "string") {
    return jsonResponse(
      { error: "Session expired. Please sign in again." },
      401,
    );
  }
  const { data: user, error: userError } = await supabase!.from("app_users")
    .select("id, email")
    .eq("id", row.user_id)
    .single();
  if (userError) throw userError;
  return jsonResponse(
    await createSession(user.id, user.email, newRefreshToken),
  );
}

async function signOut(input: Record<string, unknown>): Promise<Response> {
  if (
    typeof input.refreshToken === "string" &&
    input.refreshToken.length <= 200
  ) {
    const { error } = await supabase!.rpc("revoke_app_auth_session", {
      p_token_hash: await sha256(input.refreshToken),
    });
    if (error) throw error;
  }
  return jsonResponse({ success: true });
}

async function requestPasswordReset(
  input: Record<string, unknown>,
): Promise<Response> {
  const email = normalizeEmail(input.email);
  if (!email) {
    return jsonResponse({ error: "Enter a valid email address." }, 400);
  }
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const sender = Deno.env.get("AUTH_EMAIL_FROM");
  const resetUrl = Deno.env.get("AUTH_PASSWORD_RESET_URL");
  if (!resendApiKey || !sender || !resetUrl) {
    return jsonResponse({ error: "Password recovery is not configured." }, 503);
  }

  const { data: user, error: lookupError } = await supabase!.from("app_users")
    .select("id")
    .eq("email", email)
    .not("password_hash", "is", null)
    .maybeSingle();
  if (lookupError) throw lookupError;
  if (user) {
    const token = randomToken();
    const { error } = await supabase!.from("app_auth_password_resets").insert({
      user_id: user.id,
      token_hash: await sha256(token),
      expires_at: new Date(Date.now() + 20 * 60 * 1000).toISOString(),
    });
    if (error) throw error;

    const link = new URL(resetUrl);
    link.searchParams.set("token", token);
    await sendEmail({
      apiKey: resendApiKey,
      sender,
      recipient: email,
      subject: "Reset password Senapath",
      text:
        `Buka tautan ini untuk mengatur ulang password Senapath. Tautan berlaku 20 menit:\n${link.toString()}\n\nJika kamu tidak meminta reset, abaikan email ini.`,
    });
  }
  return jsonResponse({ success: true });
}

async function completePasswordReset(
  input: Record<string, unknown>,
): Promise<Response> {
  const token = input.token;
  const password = input.password;
  if (
    typeof token !== "string" ||
    token.length > 200 ||
    typeof password !== "string" ||
    password.length < 8 ||
    password.length > 128
  ) {
    return jsonResponse(
      { error: "Reset token or new password is invalid." },
      400,
    );
  }
  const { data, error } = await supabase!.rpc("complete_app_password_reset", {
    p_token_hash: await sha256(token),
    p_password_hash: await hashPassword(password),
  });
  if (error) throw error;
  if (data !== true) {
    return jsonResponse({ error: "Reset link expired or already used." }, 400);
  }
  return jsonResponse({ success: true });
}

async function sendEmail({
  apiKey,
  sender,
  recipient,
  subject,
  text,
}: {
  apiKey: string;
  sender: string;
  recipient: string;
  subject: string;
  text: string;
}): Promise<void> {
  if (!sender) throw new Error("AUTH_EMAIL_FROM is not configured.");
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: sender, to: [recipient], subject, text }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    console.error("Auth email delivery failed", { status: response.status });
    throw new Error("Auth email could not be sent.");
  }
}

function passwordRecoveryConfigured(): boolean {
  return Boolean(
    Deno.env.get("RESEND_API_KEY") &&
      Deno.env.get("AUTH_EMAIL_FROM") &&
      Deno.env.get("AUTH_PASSWORD_RESET_URL"),
  );
}

async function createSession(
  userId: string,
  email: string,
  existingRefreshToken?: string,
) {
  const refreshToken = existingRefreshToken ?? randomToken();
  if (!existingRefreshToken) {
    const { error } = await supabase!.from("app_auth_sessions").insert({
      user_id: userId,
      refresh_token_hash: await sha256(refreshToken),
      expires_at: new Date(
        Date.now() + refreshTokenLifetimeSeconds * 1000,
      ).toISOString(),
    });
    if (error) throw error;
  }

  const now = Math.floor(Date.now() / 1000);
  const accessToken = await new SignJWT({
    email,
    role: "authenticated",
    aud: "authenticated",
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(userId)
    .setIssuer("senapath")
    .setIssuedAt(now)
    .setExpirationTime(now + accessTokenLifetimeSeconds)
    .sign(new TextEncoder().encode(jwtSecret!));
  return {
    accessToken,
    refreshToken,
    user: { id: userId, email },
    expiresAt: (now + accessTokenLifetimeSeconds) * 1000,
  };
}

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: passwordIterations },
    key,
    256,
  );
  return `pbkdf2-sha256$${passwordIterations}$${toBase64Url(salt)}$${
    toBase64Url(new Uint8Array(bits))
  }`;
}

async function verifyPassword(
  password: string,
  encoded: string,
): Promise<boolean> {
  const [algorithm, iterationValue, saltValue, expectedValue] = encoded.split(
    "$",
  );
  const iterations = Number(iterationValue);
  if (
    algorithm !== "pbkdf2-sha256" ||
    !Number.isInteger(iterations) ||
    iterations < 100_000 ||
    iterations > 1_000_000 ||
    !saltValue ||
    !expectedValue
  ) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt: new Uint8Array(fromBase64Url(saltValue)),
      iterations,
    },
    key,
    256,
  );
  return constantTimeEqual(new Uint8Array(bits), fromBase64Url(expectedValue));
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function randomToken(): string {
  return toBase64Url(crypto.getRandomValues(new Uint8Array(32)));
}

async function sha256(value: string): Promise<string> {
  return toBase64Url(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    ),
  );
}

async function consumeRateLimit(key: string, limit: number): Promise<boolean> {
  const { data, error } = await supabase!.rpc(
    "consume_app_auth_rate_limit",
    {
      p_bucket_key: await sha256(key),
      p_limit: limit,
      p_window_seconds: 900,
    },
  );
  if (error) throw error;
  return data === true;
}

function toBase64Url(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function fromBase64Url(value: string): Uint8Array {
  const base64 = value.replaceAll("-", "+").replaceAll("_", "/");
  const binary = atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, "="));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function getErrorCode(error: unknown): string | null {
  if (!isRecord(error) || typeof error.code !== "string") return null;
  return error.code;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
