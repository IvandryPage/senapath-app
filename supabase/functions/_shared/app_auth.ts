import { jwtVerify } from "npm:jose@5.10.0";

export interface AppUserClaims {
  sub: string;
  email: string;
}

export async function verifyAppAccessToken(
  request: Request,
): Promise<AppUserClaims | null> {
  const authorization = request.headers.get("Authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  const secret = Deno.env.get("APP_AUTH_JWT_SECRET");
  if (!token || !secret) return null;

  try {
    const key = new TextEncoder().encode(secret);
    const { payload } = await jwtVerify(token, key, {
      algorithms: ["HS256"],
      audience: "authenticated",
      issuer: "senapath",
    });
    if (
      payload.role !== "authenticated" ||
      typeof payload.sub !== "string" ||
      typeof payload.email !== "string"
    ) {
      return null;
    }
    return { sub: payload.sub, email: payload.email };
  } catch {
    return null;
  }
}
