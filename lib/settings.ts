"use client";

import { useEffect, useState, useCallback } from "react";
import {
  DEFAULT_MODEL,
  DEFAULT_PROVIDER,
  PROVIDERS,
  ProviderId,
} from "./providers";

/**
 * Per-user runtime settings. Stored in localStorage so users can configure
 * their providers and models without redeploying or restarting the server.
 *
 * API keys are stored locally in the browser and forwarded to /api/chat via
 * x-mirxa-* request headers. They are never persisted on the server.
 */
export interface MirxaSettings {
  provider: ProviderId;
  model: string;
  /** Map of provider id -> API key string. */
  apiKeys: Partial<Record<ProviderId, string>>;
  /** Map of provider id -> custom base URL. */
  baseUrls: Partial<Record<ProviderId, string>>;
  /** Hugging Face token used by the model manager. */
  hfToken: string;
  /** Local Ollama base URL used by the model manager API. */
  ollamaUrl: string;
  /** Optional custom system prompt appended to the built-in agent prompt. */
  customInstructions: string;
  /** Hard cap on agent steps per turn. */
  maxSteps: number;
  /** Temperature used when the model supports it. */
  temperature: number;
}

export const DEFAULT_SETTINGS: MirxaSettings = {
  provider: DEFAULT_PROVIDER,
  model: DEFAULT_MODEL,
  apiKeys: {},
  baseUrls: {},
  hfToken: "",
  ollamaUrl: "http://localhost:11434",
  customInstructions: "",
  maxSteps: 30,
  temperature: 0.2,
};

const STORAGE_KEY = "mirxa-kali-settings-v1";

const VALID_PROVIDER_IDS = new Set<ProviderId>(PROVIDERS.map((p) => p.id));

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function sanitizeProviderMap(
  value: unknown,
): Partial<Record<ProviderId, string>> {
  if (!isRecord(value)) return {};
  const sanitized: Partial<Record<ProviderId, string>> = {};
  for (const [key, mapValue] of Object.entries(value)) {
    if (
      VALID_PROVIDER_IDS.has(key as ProviderId) &&
      typeof mapValue === "string"
    ) {
      sanitized[key as ProviderId] = mapValue;
    }
  }
  return sanitized;
}

/**
 * Coerce arbitrary JSON read from localStorage into a valid `MirxaSettings`.
 * Falls back to defaults for any field that is missing, malformed, or — in
 * the case of `provider`/`model` — references an entry that no longer exists
 * in the registry. Without this, a stale or hand-edited storage entry would
 * crash the app the next time `getProvider(settings.provider)` was called.
 */
function sanitizeSettings(value: unknown): MirxaSettings {
  if (!isRecord(value)) return DEFAULT_SETTINGS;

  const provider: ProviderId = VALID_PROVIDER_IDS.has(value.provider as ProviderId)
    ? (value.provider as ProviderId)
    : DEFAULT_PROVIDER;
  const providerWasReset = provider !== value.provider;

  return {
    provider,
    model:
      !providerWasReset && typeof value.model === "string" && value.model.length > 0
        ? value.model
        : DEFAULT_MODEL,
    apiKeys: sanitizeProviderMap(value.apiKeys),
    baseUrls: sanitizeProviderMap(value.baseUrls),
    hfToken:
      typeof value.hfToken === "string" ? value.hfToken : DEFAULT_SETTINGS.hfToken,
    ollamaUrl:
      typeof value.ollamaUrl === "string" && value.ollamaUrl.length > 0
        ? value.ollamaUrl
        : DEFAULT_SETTINGS.ollamaUrl,
    customInstructions:
      typeof value.customInstructions === "string"
        ? value.customInstructions
        : DEFAULT_SETTINGS.customInstructions,
    maxSteps:
      typeof value.maxSteps === "number" && Number.isFinite(value.maxSteps)
        ? Math.max(1, Math.min(100, Math.floor(value.maxSteps)))
        : DEFAULT_SETTINGS.maxSteps,
    temperature:
      typeof value.temperature === "number" && Number.isFinite(value.temperature)
        ? Math.max(0, Math.min(2, value.temperature))
        : DEFAULT_SETTINGS.temperature,
  };
}

export function loadSettings(): MirxaSettings {
  if (typeof window === "undefined") return DEFAULT_SETTINGS;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_SETTINGS;
    return sanitizeSettings(JSON.parse(raw));
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function saveSettings(s: MirxaSettings) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
}

/**
 * Build the headers that must be forwarded to /api/chat so the server can
 * pick the right provider/model. The values are urlencoded in case the user
 * pastes a key with non-ASCII characters.
 */
export function settingsToHeaders(s: MirxaSettings): Record<string, string> {
  const apiKey = s.apiKeys[s.provider] ?? "";
  const baseUrl = s.baseUrls[s.provider] ?? "";
  return {
    "x-mirxa-provider": s.provider,
    "x-mirxa-model": s.model,
    "x-mirxa-api-key": encodeURIComponent(apiKey),
    "x-mirxa-base-url": encodeURIComponent(baseUrl),
    "x-mirxa-instructions": encodeURIComponent(s.customInstructions),
    "x-mirxa-temperature": String(s.temperature),
  };
}

export function useSettings() {
  const [settings, setSettings] = useState<MirxaSettings>(DEFAULT_SETTINGS);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setSettings(loadSettings());
    setHydrated(true);
  }, []);

  const update = useCallback((patch: Partial<MirxaSettings>) => {
    setSettings((prev) => {
      const next = { ...prev, ...patch };
      saveSettings(next);
      return next;
    });
  }, []);

  return { settings, update, hydrated } as const;
}
