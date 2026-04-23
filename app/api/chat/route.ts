import { streamText, UIMessage } from "ai";
import { z } from "zod";
import { killDesktop } from "@/lib/e2b/utils";
import { bashTool, computerTool, resolution } from "@/lib/e2b/tool";
import { genericTools } from "@/lib/e2b/generic-tools";
import { prunedMessages } from "@/lib/utils";
import {
  DEFAULT_MODEL,
  DEFAULT_PROVIDER,
  ProviderId,
  PROVIDERS,
  getModel,
  getProvider,
  shouldUseComputerUseTool,
} from "@/lib/providers";
import { buildModel } from "@/lib/model-factory";
import { buildSystemPrompt } from "@/lib/agent-prompt";
import { DEFAULT_OLLAMA_ALLOWED_HOSTS } from "@/lib/runtime-config";
import { safeParseUrl } from "@/lib/safe-url";

export const maxDuration = 300;

const DEFAULT_TEMPERATURE = 0.2;

/**
 * Per-provider host allow-list for user-supplied `x-mirxa-base-url` headers.
 *
 * Without this, a malicious client could point any AI SDK client at an
 * arbitrary URL (cloud-metadata, internal services, …) and the server would
 * happily issue the request — a textbook SSRF. We only honor a base URL when
 * either:
 *   - the provider runs on a private/loopback address (Ollama), OR
 *   - the host matches a known public endpoint for that provider
 *     (OpenRouter, Hugging Face Router).
 *
 * For other providers we fall back to the SDK's default endpoint and ignore
 * the header entirely.
 */
const BASE_URL_ALLOWED_HOSTS: Partial<Record<ProviderId, readonly string[]>> = {
  openrouter: ["openrouter.ai"],
  huggingface: ["huggingface.co", "router.huggingface.co"],
};

function decode(v: string | null): string {
  if (!v) return "";
  try {
    return decodeURIComponent(v);
  } catch {
    return v;
  }
}

function sanitizeBaseUrl(provider: ProviderId, raw: string): string {
  if (!raw) return "";
  if (provider === "ollama") {
    // Ollama must be private/loopback unless the deployer explicitly configured
    // a different default host (for example a Docker Compose service name).
    const privateUrl = safeParseUrl(raw, { requirePrivate: true });
    if (privateUrl) return privateUrl.toString();
    if (DEFAULT_OLLAMA_ALLOWED_HOSTS.length === 0) return "";
    return (
      safeParseUrl(raw, { allowedHosts: DEFAULT_OLLAMA_ALLOWED_HOSTS })?.toString() ??
      ""
    );
  }
  const allowed = BASE_URL_ALLOWED_HOSTS[provider];
  if (!allowed) return ""; // base URL is not user-configurable for this provider
  return safeParseUrl(raw, { allowedHosts: allowed })?.toString() ?? "";
}

function readSettings(req: Request) {
  const h = req.headers;
  const providerHeader = (h.get("x-mirxa-provider") || "").trim() as ProviderId;
  const provider: ProviderId = PROVIDERS.find((p) => p.id === providerHeader)
    ? providerHeader
    : DEFAULT_PROVIDER;
  const model = (h.get("x-mirxa-model") || "").trim() || DEFAULT_MODEL;
  const apiKey = decode(h.get("x-mirxa-api-key"));
  const baseUrl = sanitizeBaseUrl(provider, decode(h.get("x-mirxa-base-url")));
  const customInstructions = decode(h.get("x-mirxa-instructions"));
  const tempRaw = h.get("x-mirxa-temperature");
  const temperature = tempRaw ? Number.parseFloat(tempRaw) : DEFAULT_TEMPERATURE;
  return {
    provider,
    model,
    apiKey,
    baseUrl,
    customInstructions,
    temperature: Number.isFinite(temperature)
      ? Math.max(0, Math.min(2, temperature))
      : DEFAULT_TEMPERATURE,
  };
}

const requestSchema = z.object({
  // Loosely typed because UIMessage shape varies across AI SDK versions; we
  // re-prune downstream. The important part is that we reject non-arrays.
  messages: z.array(z.unknown()).min(1),
  sandboxId: z.string().min(1),
});

export async function POST(req: Request) {
  let parsed: { messages: UIMessage[]; sandboxId: string };
  try {
    const json = await req.json();
    const result = requestSchema.safeParse(json);
    if (!result.success) {
      return new Response(
        JSON.stringify({
          error: "Invalid request body",
          issues: result.error.flatten(),
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }
    parsed = {
      messages: result.data.messages as UIMessage[],
      sandboxId: result.data.sandboxId,
    };
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const { messages, sandboxId } = parsed;

  const settings = readSettings(req);
  const useComputerUseTool = shouldUseComputerUseTool(
    settings.provider,
    settings.model,
  );
  const modelInfo = getModel(settings.provider, settings.model);
  // Surface a helpful error if the user requested a base URL we refused to
  // honor (e.g. pointed openrouter at a non-openrouter host).
  const rawBaseUrlHeader = decode(req.headers.get("x-mirxa-base-url"));
  if (rawBaseUrlHeader && !settings.baseUrl) {
    const providerInfo = getProvider(settings.provider);
    if (providerInfo.baseUrlConfigurable) {
      return new Response(
        JSON.stringify({
          error: `Refused base URL for ${settings.provider}: must be an allowed host (${
            BASE_URL_ALLOWED_HOSTS[settings.provider]?.join(", ") || "private/loopback"
          }).`,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }
    // Non-configurable provider: silently ignore.
  }

  try {
    const tools = useComputerUseTool
      ? {
          computer: computerTool(sandboxId),
          bash: bashTool(sandboxId),
        }
      : genericTools(sandboxId);

    const model = buildModel({
      provider: settings.provider,
      model: settings.model,
      apiKey: settings.apiKey || undefined,
      baseUrl: settings.baseUrl || undefined,
    });

    const system = buildSystemPrompt({
      isComputerUseTool: useComputerUseTool,
      isSmallModel: !!modelInfo.small,
      customInstructions: settings.customInstructions,
      resolution,
    });

    const result = streamText({
      model,
      system,
      messages: prunedMessages(messages),
      tools,
      temperature: settings.temperature,
      // Anthropic-only: enable prompt caching to keep computer-use cheap.
      providerOptions:
        settings.provider === "anthropic"
          ? { anthropic: { cacheControl: { type: "ephemeral" } } }
          : undefined,
    });

    return result.toDataStreamResponse({
      getErrorMessage(error) {
        console.error("streamText error:", error);
        if (error instanceof Error) return error.message;
        return String(error);
      },
    });
  } catch (error) {
    console.error("Chat API error:", error);
    if (sandboxId) {
      try {
        await killDesktop(sandboxId);
      } catch (cleanupError) {
        console.error("Sandbox cleanup failed:", cleanupError);
      }
    }
    const message = error instanceof Error ? error.message : "Internal Server Error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}
