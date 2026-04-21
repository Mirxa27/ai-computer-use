import { LanguageModelV1 } from "ai";
import { anthropic, createAnthropic } from "@ai-sdk/anthropic";
import { createOpenAI } from "@ai-sdk/openai";
import { createGoogleGenerativeAI } from "@ai-sdk/google";
import { createGroq } from "@ai-sdk/groq";
import { createMistral } from "@ai-sdk/mistral";
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { ProviderId, getProvider } from "./providers";

/**
 * Build a LanguageModelV1 from the user-selected provider/model. The API key
 * comes from either the per-request header (set from the /settings page) or
 * the server's environment variable. This lets users self-serve from the
 * browser without redeploying.
 */
export function buildModel(args: {
  provider: ProviderId;
  model: string;
  apiKey?: string;
  baseUrl?: string;
}): LanguageModelV1 {
  const { provider, model, apiKey, baseUrl } = args;
  const info = getProvider(provider);
  const key = apiKey || process.env[info.apiKeyEnv];

  switch (provider) {
    case "anthropic": {
      const client = key ? createAnthropic({ apiKey: key }) : anthropic;
      return client(model);
    }
    case "openai": {
      const client = createOpenAI({ apiKey: key, baseURL: baseUrl || undefined });
      return client(model);
    }
    case "google": {
      const client = createGoogleGenerativeAI({ apiKey: key });
      return client(model);
    }
    case "groq": {
      const client = createGroq({ apiKey: key });
      return client(model);
    }
    case "mistral": {
      const client = createMistral({ apiKey: key });
      return client(model);
    }
    case "openrouter": {
      const client = createOpenAICompatible({
        name: "openrouter",
        baseURL: baseUrl || info.defaultBaseUrl!,
        apiKey: key,
      });
      return client(model);
    }
    case "ollama": {
      // Ollama exposes an OpenAI-compatible endpoint at /v1.
      const client = createOpenAICompatible({
        name: "ollama",
        baseURL: baseUrl || info.defaultBaseUrl!,
        apiKey: key || "ollama",
      });
      return client(model);
    }
    case "huggingface": {
      const client = createOpenAICompatible({
        name: "huggingface",
        baseURL: baseUrl || info.defaultBaseUrl!,
        apiKey: key,
      });
      return client(model);
    }
    default: {
      const _exhaustive: never = provider;
      throw new Error(`Unhandled provider: ${_exhaustive}`);
    }
  }
}
