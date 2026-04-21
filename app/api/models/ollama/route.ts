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

const DEFAULT_OLLAMA = "http://localhost:11434";

function stripTrailingSlashes(s: string): string {
  // Avoid backtracking regex ReDoS on long strings of slashes.
  let end = s.length;
  while (end > 0 && s.charCodeAt(end - 1) === 47 /* '/' */) end--;
  return s.slice(0, end);
}

function isPrivateOrLoopback(hostname: string): boolean {
  const h = hostname.toLowerCase();
  if (h === "localhost" || h.endsWith(".localhost")) return true;
  // IPv6 loopback and link-local
  if (h === "::1" || h.startsWith("[::1") || h.startsWith("fe80:") || h.startsWith("[fe80:")) {
    return true;
  }
  // IPv4 dotted quad
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(h);
  if (!m) return false;
  const [a, b] = [Number(m[1]), Number(m[2])];
  if ([a, b].some((n) => Number.isNaN(n) || n < 0 || n > 255)) return false;
  if (a === 127) return true; // 127.0.0.0/8
  if (a === 10) return true; // 10.0.0.0/8
  if (a === 192 && b === 168) return true; // 192.168.0.0/16
  if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
  if (a === 169 && b === 254) return true; // 169.254.0.0/16 (link-local)
  return false;
}

function safeOllamaBase(input: string | null | undefined): string | null {
  const raw = (input || DEFAULT_OLLAMA).trim();
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    return null;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
  if (!isPrivateOrLoopback(parsed.hostname)) return null;
  return stripTrailingSlashes(parsed.origin + parsed.pathname);
}

function badUrlResponse() {
  return new Response(
    JSON.stringify({
      error:
        "Ollama URL must be an http(s) loopback or RFC1918 private address (e.g. http://localhost:11434).",
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
