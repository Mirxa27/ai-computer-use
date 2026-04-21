"use client";

import { useEffect, useState, useCallback } from "react";
import {
  DEFAULT_MODEL,
  DEFAULT_PROVIDER,
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

export function loadSettings(): MirxaSettings {
  if (typeof window === "undefined") return DEFAULT_SETTINGS;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_SETTINGS;
    const parsed = JSON.parse(raw) as Partial<MirxaSettings>;
    return { ...DEFAULT_SETTINGS, ...parsed };
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
