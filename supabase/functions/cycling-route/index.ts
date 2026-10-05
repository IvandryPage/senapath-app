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
  const apiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!apiKey || !supabaseUrl || !serviceRoleKey) {
    return jsonResponse(503, {
      error:
        "Layanan rute belum dikonfigurasi. Periksa GOOGLE_MAPS_API_KEY dan secrets Supabase.",
    });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON request body." });
  }
  if (!isRecord(body) || !isRecord(body.origin)) {
    return jsonResponse(400, { error: "Origin and destination are required." });
  }
  const latitude = body.origin.latitude;
  const longitude = body.origin.longitude;
  const destination = body.destination;
  if (
    typeof latitude !== "number" ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    typeof longitude !== "number" ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180 ||
    typeof destination !== "string" ||
    destination.trim().length < 2 ||
    destination.trim().length > 200
  ) {
    return jsonResponse(400, { error: "Invalid origin or destination." });
  }

  let quotaResponse: Response;
  try {
    quotaResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/consume_app_auth_rate_limit`,
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          authorization: `Bearer ${serviceRoleKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_bucket_key: await sha256(`cycling-route:${user.sub}`),
          p_limit: 30,
          p_window_seconds: 86400,
        }),
        signal: AbortSignal.timeout(10000),
      },
    );
  } catch (error) {
    console.error("Cycling route quota service unavailable", {
      error: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse(503, {
      error: "Layanan kuota pencarian rute tidak merespons.",
    });
  }
  if (!quotaResponse.ok) {
    console.error("Cycling route quota check failed", {
      status: quotaResponse.status,
    });
    return jsonResponse(503, {
      error: "Kuota pencarian rute tidak dapat diperiksa. Coba lagi nanti.",
    });
  }
  if (await quotaResponse.json() !== true) {
    return jsonResponse(429, {
      error: "Batas 30 pencarian rute per hari sudah tercapai. Coba lagi besok.",
    });
  }

  const url = new URL("https://maps.googleapis.com/maps/api/directions/json");
  url.searchParams.set("origin", `${latitude},${longitude}`);
  url.searchParams.set("destination", destination.trim());
  url.searchParams.set("mode", "bicycling");
  url.searchParams.set("language", "id");
  url.searchParams.set("key", apiKey);

  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(12000) });
    if (!response.ok) {
      console.error("Google Directions request failed", {
        status: response.status,
      });
      return jsonResponse(502, {
        error: "Google Maps tidak dapat menghitung rute saat ini.",
      });
    }
    const result: unknown = await response.json();
    if (!isRecord(result) || typeof result.status !== "string") {
      return jsonResponse(502, { error: "Respons Google Maps tidak valid." });
    }
    if (result.status !== "OK") {
      console.error("Google Directions returned a non-OK status", {
        status: result.status,
      });
      const message = result.status === "ZERO_RESULTS"
        ? "Google Maps tidak menemukan rute sepeda untuk tujuan tersebut."
        : result.status === "REQUEST_DENIED"
        ? "Permintaan Google Maps ditolak. Periksa API Directions dan billing."
        : "Rute sepeda tidak tersedia untuk lokasi ini.";
      return jsonResponse(404, { error: message });
    }
    const routes = result.routes;
    const route = Array.isArray(routes) ? routes[0] : null;
    if (!isRecord(route) || !isRecord(route.overview_polyline)) {
      return jsonResponse(404, {
        error: "Google Maps tidak mengembalikan jalur untuk tujuan tersebut.",
      });
    }
    const encoded = route.overview_polyline.points;
    const legs = route.legs;
    const leg = Array.isArray(legs) ? legs[0] : null;
    const distance = isRecord(leg) ? leg.distance : null;
    const duration = isRecord(leg) ? leg.duration : null;
    if (
      typeof encoded !== "string" ||
      !isRecord(distance) ||
      typeof distance.value !== "number" ||
      !isRecord(duration) ||
      typeof duration.value !== "number"
    ) {
      return jsonResponse(502, {
        error: "Detail rute Google Maps tidak lengkap.",
      });
    }
    const points = decodePolyline(encoded);
    if (points.length < 2 || points.length > 12000) {
      return jsonResponse(502, {
        error: "Geometri rute Google Maps tidak valid.",
      });
    }
    return jsonResponse(200, {
      name: typeof leg.end_address === "string"
        ? leg.end_address
        : destination.trim(),
      distanceMeters: distance.value,
      durationSeconds: duration.value,
      points,
    });
  } catch (error) {
    console.error("Google Directions service unavailable", {
      error: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse(502, {
      error: "Layanan Google Maps tidak merespons. Coba lagi nanti.",
    });
  }
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function sha256(value: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  let binary = "";
  for (const byte of digest) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function decodePolyline(encoded: string): Array<{
  latitude: number;
  longitude: number;
}> {
  const points: Array<{ latitude: number; longitude: number }> = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;
  while (index < encoded.length) {
    const lat = decodeValue(encoded, index);
    index = lat.nextIndex;
    latitude += lat.value;
    const lng = decodeValue(encoded, index);
    index = lng.nextIndex;
    longitude += lng.value;
    points.push({
      latitude: latitude / 1e5,
      longitude: longitude / 1e5,
    });
  }
  return points;
}

function decodeValue(
  encoded: string,
  start: number,
): { value: number; nextIndex: number } {
  let result = 0;
  let shift = 0;
  let index = start;
  let byte: number;
  do {
    if (index >= encoded.length || shift > 30) {
      throw new Error("Malformed encoded polyline.");
    }
    byte = encoded.charCodeAt(index++) - 63;
    if (byte < 0 || byte > 63) {
      throw new Error("Malformed encoded polyline.");
    }
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  const value = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
  return { value, nextIndex: index };
}
