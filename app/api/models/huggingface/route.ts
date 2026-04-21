/**
 * Hugging Face model search.
 *
 * Proxies the HF Hub `/api/models` endpoint. Used by the /settings model
 * manager so the user can search the public Hub for vision-capable models
 * to pull into their local Ollama instance.
 *
 * The HF token, if provided, is forwarded so the user can also see their
 * private models.
 */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const search = url.searchParams.get("search") ?? "";
  const filter = url.searchParams.get("filter") ?? "text-generation";
  const limit = Math.min(
    Number.parseInt(url.searchParams.get("limit") ?? "20", 10) || 20,
    50,
  );
  const token = req.headers.get("x-hf-token") || process.env.HF_TOKEN || "";

  const hfUrl = new URL("https://huggingface.co/api/models");
  if (search) hfUrl.searchParams.set("search", search);
  if (filter) hfUrl.searchParams.set("filter", filter);
  hfUrl.searchParams.set("limit", String(limit));
  hfUrl.searchParams.set("full", "false");
  hfUrl.searchParams.set("sort", "downloads");
  hfUrl.searchParams.set("direction", "-1");

  try {
    const res = await fetch(hfUrl.toString(), {
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
      next: { revalidate: 60 },
    });
    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: `Hugging Face responded ${res.status}` }),
        { status: res.status, headers: { "Content-Type": "application/json" } },
      );
    }
    const data = (await res.json()) as Array<{
      id: string;
      modelId?: string;
      downloads?: number;
      likes?: number;
      pipeline_tag?: string;
      tags?: string[];
    }>;
    const models = data.map((m) => ({
      id: m.id ?? m.modelId,
      downloads: m.downloads ?? 0,
      likes: m.likes ?? 0,
      pipeline_tag: m.pipeline_tag,
      tags: m.tags ?? [],
    }));
    return Response.json({ models });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "fetch failed",
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
}
