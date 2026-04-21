import { streamText, UIMessage } from "ai";
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
  shouldUseComputerUseTool,
} from "@/lib/providers";
import { buildModel } from "@/lib/model-factory";
import { buildSystemPrompt } from "@/lib/agent-prompt";

export const maxDuration = 300;

function decode(v: string | null): string {
  if (!v) return "";
  try {
    return decodeURIComponent(v);
  } catch {
    return v;
  }
}

function readSettings(req: Request) {
  const h = req.headers;
  const providerHeader = (h.get("x-mirxa-provider") || "").trim() as ProviderId;
  const provider: ProviderId = PROVIDERS.find((p) => p.id === providerHeader)
    ? providerHeader
    : DEFAULT_PROVIDER;
  const model = (h.get("x-mirxa-model") || "").trim() || DEFAULT_MODEL;
  const apiKey = decode(h.get("x-mirxa-api-key"));
  const baseUrl = decode(h.get("x-mirxa-base-url"));
  const customInstructions = decode(h.get("x-mirxa-instructions"));
  const tempRaw = h.get("x-mirxa-temperature");
  const temperature = tempRaw ? Number.parseFloat(tempRaw) : 0.2;
  return {
    provider,
    model,
    apiKey,
    baseUrl,
    customInstructions,
    temperature: Number.isFinite(temperature) ? temperature : 0.2,
  };
}

export async function POST(req: Request) {
  const { messages, sandboxId }: { messages: UIMessage[]; sandboxId: string } =
    await req.json();

  const settings = readSettings(req);
  const useComputerUseTool = shouldUseComputerUseTool(
    settings.provider,
    settings.model,
  );
  const modelInfo = getModel(settings.provider, settings.model);

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
