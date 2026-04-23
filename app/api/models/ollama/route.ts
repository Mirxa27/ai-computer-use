/**
 * Local Ollama bridge.
 *
 * - GET ?url=<ollama-base>             -> list installed models (`/api/tags`)
 * - POST { name, ollamaUrl }           -> stream a `pull` (download) of the model.
 *   `name` may be a regular Ollama tag (`llama3.2-vision:11b`) OR a Hugging
 *   Face GGUF reference using Ollama's `hf.co/<repo>` shorthand
 *   (`hf.co/Qwen/Qwen2.5-VL-7B-Instruct-GGUF`). Ollama 0.3.13+ resolves the
 *   GGUF directly from the Hub, so this is a real "download any HF model" path
 *   that uses the user's HF token if provided.
 *
 * Streams progress back to the browser as Server-Sent JSON lines so the
 * /settings UI can show a real progress bar.
 *
 * SECURITY: the Ollama base URL is user-controlled, so we strictly validate
 * it against an allow-list (loopback + RFC1918 private ranges, http/https
 * only) before issuing the server-side fetch. This blocks SSRF against
 * arbitrary internet hosts or cloud metadata endpoints.
 */

import { DEFAULT_OLLAMA_ALLOWED_HOSTS } from "@/lib/runtime-config";
import { safeParseUrl, stripTrailingSlashes } from "@/lib/safe-url";

const DEFAULT_OLLAMA = "http://localhost:11434";

function parseSafeOllamaUrl(raw: string): URL | null {
  const privateUrl = safeParseUrl(raw, { requirePrivate: true });
  if (privateUrl) return privateUrl;
  if (DEFAULT_OLLAMA_ALLOWED_HOSTS.length === 0) return null;
  return safeParseUrl(raw, { allowedHosts: DEFAULT_OLLAMA_ALLOWED_HOSTS });
}

function safeOllamaBase(input: string | null | undefined): string | null {
  const parsed = parseSafeOllamaUrl(input || DEFAULT_OLLAMA);
  if (!parsed) return null;
  // Users may paste an OpenAI-compatible base like `http://localhost:11434/v1`
  // (that's the URL the AI SDK uses to talk to Ollama). The native Ollama
  // management API lives at the root, so strip a trailing `/v1` segment so
  // `${base}/api/tags` and `${base}/api/pull` keep working.
  let pathname = stripTrailingSlashes(parsed.pathname);
  if (pathname === "/v1" || pathname.endsWith("/v1")) {
    pathname = stripTrailingSlashes(pathname.slice(0, -3));
  }
  return stripTrailingSlashes(parsed.origin + pathname);
}

function badUrlResponse() {
  const hostHint =
    DEFAULT_OLLAMA_ALLOWED_HOSTS.length > 0
      ? ` or match the configured Ollama host (${DEFAULT_OLLAMA_ALLOWED_HOSTS.join(", ")})`
      : "";
  return new Response(
    JSON.stringify({
      error:
        `Ollama URL must be an http(s) loopback or RFC1918 private address${hostHint} (e.g. http://localhost:11434).`,
    }),
    { status: 400, headers: { "Content-Type": "application/json" } },
  );
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const ollamaBase = safeOllamaBase(url.searchParams.get("url"));
  if (!ollamaBase) return badUrlResponse();
  try {
    const res = await fetch(`${ollamaBase}/api/tags`);
    if (!res.ok) {
      return new Response(
        JSON.stringify({
          error: `Ollama responded ${res.status} at ${ollamaBase}`,
        }),
        { status: res.status, headers: { "Content-Type": "application/json" } },
      );
    }
    const data = await res.json();
    return Response.json(data);
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: `Could not reach Ollama at ${ollamaBase}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
}

interface PullBody {
  name: string;
  ollamaUrl?: string;
}

export async function POST(req: Request) {
  let body: PullBody;
  try {
    body = (await req.json()) as PullBody;
  } catch {
    return new Response(JSON.stringify({ error: "invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const name = (body.name || "").trim();
  if (!name) {
    return new Response(JSON.stringify({ error: "name is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const ollamaBase = safeOllamaBase(body.ollamaUrl);
  if (!ollamaBase) return badUrlResponse();
  const hfToken = req.headers.get("x-hf-token") || process.env.HF_TOKEN || "";

  let upstream: Response;
  try {
    upstream = await fetch(`${ollamaBase}/api/pull`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // Ollama forwards Authorization to hf.co for hf.co/* model refs.
        ...(hfToken ? { Authorization: `Bearer ${hfToken}` } : {}),
      },
      body: JSON.stringify({ name, stream: true }),
    });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: `Could not reach Ollama at ${ollamaBase}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!upstream.ok || !upstream.body) {
    const text = await upstream.text().catch(() => "");
    return new Response(
      JSON.stringify({
        error: `Ollama pull failed (${upstream.status}): ${text || "no body"}`,
      }),
      {
        status: upstream.status || 502,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  // Pass the streamed NDJSON straight through. Ollama already emits one JSON
  // object per line with progress info; the client can read it incrementally.
  return new Response(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": "application/x-ndjson",
      "Cache-Control": "no-cache, no-transform",
    },
  });
}
