const FALLBACK_APP_URL = "http://localhost:3000";
const FALLBACK_OLLAMA_URL = "http://localhost:11434";

function removeTrailingSlashes(value: string): string {
  return value.replace(/\/+$/, "");
}

function readPublicEnv(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value ? removeTrailingSlashes(value) : undefined;
}

export const DEFAULT_APP_URL =
  readPublicEnv("NEXT_PUBLIC_APP_URL") ?? FALLBACK_APP_URL;

export const DEFAULT_OLLAMA_URL =
  readPublicEnv("NEXT_PUBLIC_DEFAULT_OLLAMA_URL") ?? FALLBACK_OLLAMA_URL;

export const DEFAULT_OLLAMA_API_URL = DEFAULT_OLLAMA_URL.endsWith("/v1")
  ? DEFAULT_OLLAMA_URL
  : `${DEFAULT_OLLAMA_URL}/v1`;
