// Supabase Edge Function: ocr-extract
//
// Production OCR endpoint. The browser hands us a storage path; we download
// the file with the service-role key, run Google Cloud Vision
// DOCUMENT_TEXT_DETECTION on it, and return the recognized text. Mirrors the
// dev-only TanStack server function at src/lib/ocr/googleVision.server.ts but
// rewritten for the Deno + edge-runtime sandbox (Web Crypto, no node:crypto).
//
// Required env (set on the self-hosted Supabase EC2 box's docker .env or via
// `supabase secrets set` for cloud-hosted; restart the functions container
// after adding):
//   GOOGLE_OCR_CREDENTIALS   single-line JSON of the GCP service-account key
//   SUPABASE_URL             auto-injected by the Supabase Functions runtime
//   SUPABASE_SERVICE_ROLE_KEY  auto-injected ditto

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const VISION_IMAGE_URL = "https://vision.googleapis.com/v1/images:annotate";
const VISION_FILE_URL  = "https://vision.googleapis.com/v1/files:annotate";
const TOKEN_SCOPE      = "https://www.googleapis.com/auth/cloud-platform";
const JWT_TTL_SECONDS  = 3600;
const BUCKET           = "lims-files"; // keep in sync with src/lib/ocr/agreementOcr.ts

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri: string;
};

// ── Service-account loading ────────────────────────────────────────────────

function stripWrappingQuotes(s: string): string {
  const t = s.trim();
  if (t.length >= 2 && ((t[0] === '"' && t.at(-1) === '"') || (t[0] === "'" && t.at(-1) === "'"))) {
    return t.slice(1, -1);
  }
  return t;
}

function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("GOOGLE_OCR_CREDENTIALS");
  if (!raw?.trim()) {
    throw new Error("GOOGLE_OCR_CREDENTIALS env var is not set on the Edge Functions runtime");
  }
  const sa = JSON.parse(stripWrappingQuotes(raw)) as ServiceAccount;
  if (!sa.client_email || !sa.private_key) {
    throw new Error("GOOGLE_OCR_CREDENTIALS is missing client_email or private_key");
  }
  if (!sa.token_uri) sa.token_uri = "https://oauth2.googleapis.com/token";
  return sa;
}

// ── Base64 helpers (Uint8Array <-> base64 / base64url) ─────────────────────

function bytesToBase64(bytes: Uint8Array): string {
  // chunked to avoid call-stack overflow on large files
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(bin);
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// ── JWT signing via Web Crypto (RS256) ─────────────────────────────────────

// Strips the PEM header/footer and base64-decodes the inner body. Service-
// account private keys come as PKCS#8 ("-----BEGIN PRIVATE KEY-----") which
// Web Crypto importKey accepts directly.
function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\\n/g, "\n") // env-stored keys often have escaped newlines
    .replace(/\s+/g, "");
  return base64ToBytes(body).buffer as ArrayBuffer;
}

async function signJwt(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim  = base64UrlEncode(JSON.stringify({
    iss:   sa.client_email,
    scope: TOKEN_SCOPE,
    aud:   sa.token_uri,
    iat:   now,
    exp:   now + JWT_TTL_SECONDS,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claim}`)),
  );
  return `${header}.${claim}.${base64UrlEncode(sig)}`;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: await signJwt(sa),
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.access_token) {
    throw new Error(`Google auth failed: ${body.error_description ?? body.error ?? res.status}`);
  }
  return body.access_token as string;
}

// ── Vision REST calls ──────────────────────────────────────────────────────

async function visionPost(url: string, token: string, requests: unknown): Promise<any> {
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ requests }),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`Vision API error (${res.status}): ${json?.error?.message ?? "unknown"}`);
  }
  return json;
}

async function extractFromImage(token: string, base64: string): Promise<string> {
  const json = await visionPost(VISION_IMAGE_URL, token, [
    { image: { content: base64 }, features: [{ type: "DOCUMENT_TEXT_DETECTION" }] },
  ]);
  return json?.responses?.[0]?.fullTextAnnotation?.text ?? "";
}

async function extractFromPdf(token: string, base64: string): Promise<string> {
  // files:annotate handles up to 5 pages synchronously — enough for agreements/specs.
  const json = await visionPost(VISION_FILE_URL, token, [
    {
      inputConfig: { mimeType: "application/pdf", content: base64 },
      features:    [{ type: "DOCUMENT_TEXT_DETECTION" }],
    },
  ]);
  const pages: any[] = json?.responses?.[0]?.responses ?? [];
  return pages.map((p) => p?.fullTextAnnotation?.text ?? "").filter(Boolean).join("\n\n");
}

// ── HTTP entry point ───────────────────────────────────────────────────────

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST")    return jsonResponse(405, { ok: false, message: "method not allowed" });

  try {
    const { path, fileName } = await req.json().catch(() => ({}));
    if (!path || typeof path !== "string") {
      return jsonResponse(400, { ok: false, message: "`path` is required" });
    }

    // 1. Download the file from Supabase Storage with the service-role key.
    //    Both env vars are auto-injected by the Supabase Functions runtime.
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not available in this runtime");
    }
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: blob, error } = await supabase.storage.from(BUCKET).download(path);
    if (error || !blob) {
      return jsonResponse(404, { ok: false, message: `Could not download ${path}: ${error?.message ?? "not found"}` });
    }
    const bytes  = new Uint8Array(await blob.arrayBuffer());
    const base64 = bytesToBase64(bytes);

    // 2. Decide image vs PDF from filename extension (client always sends one).
    const ext   = (fileName ?? path).split(".").pop()?.toLowerCase() ?? "";
    const isPdf = ext === "pdf";

    // 3. Mint a Google OAuth access token and call Vision.
    const sa    = loadServiceAccount();
    const token = await getAccessToken(sa);
    const text  = isPdf ? await extractFromPdf(token, base64) : await extractFromImage(token, base64);

    if (!text.trim()) {
      return jsonResponse(200, { ok: false, message: "No readable text found in the document" });
    }
    return jsonResponse(200, { ok: true, text });
  } catch (err) {
    console.error("ocr-extract failed:", err);
    return jsonResponse(500, { ok: false, message: (err as Error)?.message ?? "OCR failed" });
  }
});
