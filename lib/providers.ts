/**
 * Provider/model registry for MirXa Kali.
 *
 * Each provider entry describes:
 * - id: stable internal identifier
 * - label: human readable name
 * - apiKeyName: which settings key holds the API key for this provider
 * - supportsComputerUse: true only for Anthropic models that support the
 *   Anthropic-specific computer-use beta tools. Everything else uses our
 *   generic screenshot/click/type/key/scroll/drag/bash tool set so that even
 *   small models can drive the desktop.
 * - models: a curated, real list of models known to work with the AI SDK at
 *   the time of writing. Users can also type a custom model id from /settings.
 */
export type ProviderId =
  | "anthropic"
  | "openai"
  | "google"
  | "groq"
  | "mistral"
  | "openrouter"
  | "ollama"
  | "huggingface";

export interface ModelInfo {
  id: string;
  label: string;
  /** Recommended for vision / screenshot reasoning */
  vision?: boolean;
  /** Best-effort hint that this is a "small" model and should use the
   * compact/fallback tool set + tighter prompts. */
  small?: boolean;
  /** Explicitly opt this model into the Anthropic computer-use beta tools.
   * Only set this for Anthropic models that Anthropic has confirmed support
   * `computer_20250124`. */
  computerUse?: boolean;
}

export interface ProviderInfo {
  id: ProviderId;
  label: string;
  apiKeyEnv: string;
  apiKeyLabel: string;
  /** Does this provider's selected models support Anthropic computer-use beta? */
  supportsComputerUseTool: boolean;
  /** Default base URL (used for OpenAI-compatible providers). */
  defaultBaseUrl?: string;
  /** Whether the user can override the base URL from /settings. */
  baseUrlConfigurable?: boolean;
  models: ModelInfo[];
  notes?: string;
}

export const PROVIDERS: ProviderInfo[] = [
  {
    id: "anthropic",
    label: "Anthropic",
    apiKeyEnv: "ANTHROPIC_API_KEY",
    apiKeyLabel: "Anthropic API key",
    supportsComputerUseTool: true,
    models: [
      { id: "claude-3-7-sonnet-20250219", label: "Claude 3.7 Sonnet (computer use)", vision: true, computerUse: true },
      { id: "claude-3-5-sonnet-20241022", label: "Claude 3.5 Sonnet v2 (computer use)", vision: true, computerUse: true },
      { id: "claude-3-5-haiku-20241022", label: "Claude 3.5 Haiku", small: true },
    ],
  },
  {
    id: "openai",
    label: "OpenAI",
    apiKeyEnv: "OPENAI_API_KEY",
    apiKeyLabel: "OpenAI API key",
    supportsComputerUseTool: false,
    models: [
      { id: "gpt-4o", label: "GPT-4o", vision: true },
      { id: "gpt-4o-mini", label: "GPT-4o mini", vision: true, small: true },
      { id: "gpt-4.1", label: "GPT-4.1", vision: true },
      { id: "gpt-4.1-mini", label: "GPT-4.1 mini", vision: true, small: true },
    ],
  },
  {
    id: "google",
    label: "Google Gemini",
    apiKeyEnv: "GOOGLE_GENERATIVE_AI_API_KEY",
    apiKeyLabel: "Google AI Studio key",
    supportsComputerUseTool: false,
    models: [
      { id: "gemini-2.0-flash", label: "Gemini 2.0 Flash", vision: true, small: true },
      { id: "gemini-1.5-pro-latest", label: "Gemini 1.5 Pro", vision: true },
      { id: "gemini-1.5-flash-latest", label: "Gemini 1.5 Flash", vision: true, small: true },
    ],
  },
  {
    id: "groq",
    label: "Groq",
    apiKeyEnv: "GROQ_API_KEY",
    apiKeyLabel: "Groq API key",
    supportsComputerUseTool: false,
    models: [
      { id: "llama-3.2-90b-vision-preview", label: "Llama 3.2 90B Vision", vision: true },
      { id: "llama-3.2-11b-vision-preview", label: "Llama 3.2 11B Vision", vision: true, small: true },
      { id: "llama-3.3-70b-versatile", label: "Llama 3.3 70B Versatile" },
    ],
    notes: "Vision models recommended — the agent must read screenshots.",
  },
  {
    id: "mistral",
    label: "Mistral",
    apiKeyEnv: "MISTRAL_API_KEY",
    apiKeyLabel: "Mistral API key",
    supportsComputerUseTool: false,
    models: [
      { id: "pixtral-large-latest", label: "Pixtral Large (vision)", vision: true },
      { id: "pixtral-12b-2409", label: "Pixtral 12B (vision)", vision: true, small: true },
      { id: "mistral-large-latest", label: "Mistral Large" },
    ],
  },
  {
    id: "openrouter",
    label: "OpenRouter",
    apiKeyEnv: "OPENROUTER_API_KEY",
    apiKeyLabel: "OpenRouter API key",
    supportsComputerUseTool: false,
    defaultBaseUrl: "https://openrouter.ai/api/v1",
    baseUrlConfigurable: true,
    models: [
      { id: "anthropic/claude-3.5-sonnet", label: "Claude 3.5 Sonnet (via OpenRouter)", vision: true },
      { id: "openai/gpt-4o-mini", label: "GPT-4o mini (via OpenRouter)", vision: true, small: true },
      { id: "qwen/qwen-2.5-vl-72b-instruct", label: "Qwen 2.5 VL 72B", vision: true },
    ],
  },
  {
    id: "ollama",
    label: "Ollama (local)",
    apiKeyEnv: "OLLAMA_API_KEY",
    apiKeyLabel: "Ollama API key (optional)",
    supportsComputerUseTool: false,
    defaultBaseUrl: "http://localhost:11434/v1",
    baseUrlConfigurable: true,
    models: [
      { id: "llama3.2-vision:11b", label: "Llama 3.2 Vision 11B", vision: true, small: true },
      { id: "llava:13b", label: "LLaVA 13B", vision: true, small: true },
      { id: "qwen2.5vl:7b", label: "Qwen 2.5 VL 7B", vision: true, small: true },
    ],
    notes:
      "Run Ollama locally then download a vision model with the Models tab. Small models work — the agent uses a compact tool set automatically.",
  },
  {
    id: "huggingface",
    label: "Hugging Face Inference",
    apiKeyEnv: "HF_TOKEN",
    apiKeyLabel: "Hugging Face access token",
    supportsComputerUseTool: false,
    defaultBaseUrl: "https://router.huggingface.co/v1",
    baseUrlConfigurable: true,
    models: [
      { id: "meta-llama/Llama-3.2-11B-Vision-Instruct", label: "Llama 3.2 11B Vision", vision: true, small: true },
      { id: "Qwen/Qwen2.5-VL-7B-Instruct", label: "Qwen 2.5 VL 7B Instruct", vision: true, small: true },
    ],
    notes: "Uses the OpenAI-compatible HF Inference Router.",
  },
];

export const DEFAULT_PROVIDER: ProviderId = "anthropic";
export const DEFAULT_MODEL = "claude-3-7-sonnet-20250219";

export function getProvider(id: ProviderId): ProviderInfo {
  const p = PROVIDERS.find((x) => x.id === id);
  if (!p) throw new Error(`Unknown provider: ${id}`);
  return p;
}

export function getModel(providerId: ProviderId, modelId: string): ModelInfo {
  const p = getProvider(providerId);
  return (
    p.models.find((m) => m.id === modelId) ?? {
      id: modelId,
      label: modelId,
      // We can't know — assume small to be safe (uses compact tool set).
      small: true,
    }
  );
}

/**
 * Decides whether to use the Anthropic computer-use beta tools or our generic
 * cross-provider tool set. Computer use is only enabled for Anthropic models
 * that are explicitly opted in via `ModelInfo.computerUse = true` in the
 * registry above. Unknown / typo'd / future model ids therefore default to
 * the safe generic tool set.
 */
export function shouldUseComputerUseTool(
  providerId: ProviderId,
  modelId: string,
): boolean {
  if (providerId !== "anthropic") return false;
  const provider = PROVIDERS.find((p) => p.id === providerId);
  const model = provider?.models.find((m) => m.id === modelId);
  return model?.computerUse === true;
}
