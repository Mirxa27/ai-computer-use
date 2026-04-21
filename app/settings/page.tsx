"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { ArrowLeft, Download, RefreshCw, Search } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  PROVIDERS,
  ProviderId,
  getProvider,
} from "@/lib/providers";
import { useSettings } from "@/lib/settings";
import { MirxaKaliMark } from "@/components/icons";

interface OllamaModel {
  name: string;
  size: number;
}

interface HfModel {
  id: string;
  downloads: number;
  likes: number;
  pipeline_tag?: string;
  tags: string[];
}

function formatBytes(b: number): string {
  if (!b) return "0";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let i = 0;
  let v = b;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(1)} ${units[i]}`;
}

export default function SettingsPage() {
  const { settings, update, hydrated } = useSettings();
  const provider = getProvider(settings.provider);
  const apiKey = settings.apiKeys[settings.provider] ?? "";
  const baseUrl = settings.baseUrls[settings.provider] ?? "";

  // ---------------- Hugging Face search ----------------
  const [hfQuery, setHfQuery] = useState("vision");
  const [hfModels, setHfModels] = useState<HfModel[]>([]);
  const [hfLoading, setHfLoading] = useState(false);

  const searchHf = async () => {
    setHfLoading(true);
    try {
      const res = await fetch(
        `/api/models/huggingface?search=${encodeURIComponent(hfQuery)}&limit=20`,
        { headers: settings.hfToken ? { "x-hf-token": settings.hfToken } : {} },
      );
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      setHfModels(data.models || []);
    } catch (e) {
      toast.error("Hugging Face search failed", {
        description: e instanceof Error ? e.message : String(e),
      });
    } finally {
      setHfLoading(false);
    }
  };

  // ---------------- Ollama installed models ----------------
  const [installed, setInstalled] = useState<OllamaModel[]>([]);
  const [installedError, setInstalledError] = useState<string | null>(null);
  const [installedLoading, setInstalledLoading] = useState(false);

  const loadInstalled = useMemo(
    () => async () => {
      setInstalledLoading(true);
      setInstalledError(null);
      try {
        const res = await fetch(
          `/api/models/ollama?url=${encodeURIComponent(settings.ollamaUrl)}`,
        );
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
        setInstalled(data.models || []);
      } catch (e) {
        setInstalledError(e instanceof Error ? e.message : String(e));
        setInstalled([]);
      } finally {
        setInstalledLoading(false);
      }
    },
    [settings.ollamaUrl],
  );

  useEffect(() => {
    if (hydrated) loadInstalled();
  }, [hydrated, loadInstalled]);

  // ---------------- Pull a model ----------------
  const [pullName, setPullName] = useState("");
  const [pullProgress, setPullProgress] = useState<string | null>(null);
  const [pulling, setPulling] = useState(false);

  const pullModel = async (name: string) => {
    if (!name) return;
    setPulling(true);
    setPullProgress(`Starting pull of ${name}…`);
    try {
      const res = await fetch("/api/models/ollama", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(settings.hfToken ? { "x-hf-token": settings.hfToken } : {}),
        },
        body: JSON.stringify({ name, ollamaUrl: settings.ollamaUrl }),
      });
      if (!res.ok || !res.body) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || `HTTP ${res.status}`);
      }
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";
        for (const line of lines) {
          if (!line.trim()) continue;
          try {
            const obj = JSON.parse(line) as {
              status?: string;
              completed?: number;
              total?: number;
            };
            if (obj.total && obj.completed != null) {
              const pct = ((obj.completed / obj.total) * 100).toFixed(1);
              setPullProgress(
                `${obj.status ?? "downloading"}: ${pct}% (${formatBytes(
                  obj.completed,
                )}/${formatBytes(obj.total)})`,
              );
            } else if (obj.status) {
              setPullProgress(obj.status);
            }
          } catch {
            // ignore non-JSON lines
          }
        }
      }
      toast.success(`Downloaded ${name}`);
      setPullProgress(null);
      loadInstalled();
    } catch (e) {
      toast.error("Pull failed", {
        description: e instanceof Error ? e.message : String(e),
      });
      setPullProgress(null);
    } finally {
      setPulling(false);
    }
  };

  if (!hydrated) {
    return (
      <div className="min-h-screen flex items-center justify-center text-zinc-400">
        Loading settings…
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="border-b border-zinc-800 bg-zinc-950/60 backdrop-blur sticky top-0 z-10">
        <div className="mx-auto max-w-5xl px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link
              href="/"
              className="flex items-center gap-2 text-zinc-400 hover:text-zinc-100"
            >
              <ArrowLeft className="size-4" /> Back
            </Link>
            <span className="mx-2 text-zinc-700">|</span>
            <MirxaKaliMark />
          </div>
          <span className="text-xs text-zinc-500">Settings</span>
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-6 py-8 space-y-10">
        {/* Provider & model */}
        <section className="space-y-4">
          <h2 className="text-xl font-semibold">AI provider & model</h2>
          <p className="text-sm text-zinc-400">
            Choose any supported provider. Anthropic Claude Sonnet uses the
            full computer-use tool. Every other provider — including small
            local models — uses the cross-provider tool set so the agent can
            still drive the desktop reliably.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Provider</Label>
              <select
                className="w-full rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2 text-sm"
                value={settings.provider}
                onChange={(e) => {
                  const p = e.target.value as ProviderId;
                  const first = getProvider(p).models[0]?.id ?? "";
                  update({ provider: p, model: first });
                }}
              >
                {PROVIDERS.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.label}
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              <Label>Model</Label>
              <input
                list="model-options"
                className="w-full rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2 text-sm"
                value={settings.model}
                onChange={(e) => update({ model: e.target.value })}
                placeholder="e.g. claude-3-7-sonnet-20250219"
              />
              <datalist id="model-options">
                {provider.models.map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.label}
                  </option>
                ))}
              </datalist>
              {provider.notes && (
                <p className="text-xs text-zinc-500">{provider.notes}</p>
              )}
            </div>

            <div className="space-y-2">
              <Label>{provider.apiKeyLabel}</Label>
              <Input
                type="password"
                value={apiKey}
                onChange={(e) =>
                  update({
                    apiKeys: {
                      ...settings.apiKeys,
                      [settings.provider]: e.target.value,
                    },
                  })
                }
                placeholder={`set ${provider.apiKeyEnv} on the server, or paste a key here`}
              />
              <p className="text-xs text-zinc-500">
                Stored in your browser only. Sent to <code>/api/chat</code> as
                an <code>x-mirxa-api-key</code> header for this session.
              </p>
            </div>

            {provider.baseUrlConfigurable && (
              <div className="space-y-2">
                <Label>Base URL</Label>
                <Input
                  value={baseUrl}
                  onChange={(e) =>
                    update({
                      baseUrls: {
                        ...settings.baseUrls,
                        [settings.provider]: e.target.value,
                      },
                    })
                  }
                  placeholder={provider.defaultBaseUrl}
                />
              </div>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Temperature ({settings.temperature.toFixed(2)})</Label>
              <input
                type="range"
                min={0}
                max={1.5}
                step={0.05}
                value={settings.temperature}
                onChange={(e) =>
                  update({ temperature: Number.parseFloat(e.target.value) })
                }
                className="w-full accent-emerald-500"
              />
            </div>
            <div className="space-y-2">
              <Label>Max steps per turn</Label>
              <Input
                type="number"
                min={1}
                max={100}
                value={settings.maxSteps}
                onChange={(e) =>
                  update({
                    maxSteps: Math.max(
                      1,
                      Math.min(100, Number.parseInt(e.target.value, 10) || 1),
                    ),
                  })
                }
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label>Custom instructions (appended to system prompt)</Label>
            <textarea
              className="w-full rounded-md border border-zinc-800 bg-zinc-900 px-3 py-2 text-sm min-h-[100px]"
              value={settings.customInstructions}
              onChange={(e) => update({ customInstructions: e.target.value })}
              placeholder="e.g. Always respond in concise bullet points. Prefer Firefox over Chromium."
            />
          </div>
        </section>

        {/* Local models */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">Local models (Ollama)</h2>
            <Button
              variant="outline"
              size="sm"
              onClick={loadInstalled}
              disabled={installedLoading}
            >
              <RefreshCw
                className={`size-4 ${installedLoading ? "animate-spin" : ""}`}
              />
              Refresh
            </Button>
          </div>
          <p className="text-sm text-zinc-400">
            Run a local Ollama server and MirXa Kali will use it as a real
            provider — including for any GGUF model from Hugging Face via the{" "}
            <code>hf.co/&lt;repo&gt;</code> shorthand.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Ollama base URL</Label>
              <Input
                value={settings.ollamaUrl}
                onChange={(e) => update({ ollamaUrl: e.target.value })}
                placeholder="http://localhost:11434"
              />
            </div>
            <div className="space-y-2">
              <Label>Hugging Face token (for private/gated models)</Label>
              <Input
                type="password"
                value={settings.hfToken}
                onChange={(e) => update({ hfToken: e.target.value })}
                placeholder="hf_..."
              />
            </div>
          </div>

          <div className="rounded-md border border-zinc-800 bg-zinc-900/40 divide-y divide-zinc-800">
            {installedError && (
              <div className="p-3 text-xs text-red-400">{installedError}</div>
            )}
            {installed.length === 0 && !installedError && !installedLoading && (
              <div className="p-3 text-xs text-zinc-500">
                No local models installed yet. Pull one below.
              </div>
            )}
            {installed.map((m) => (
              <div
                key={m.name}
                className="p-3 flex items-center justify-between text-sm"
              >
                <div>
                  <div className="font-mono">{m.name}</div>
                  <div className="text-xs text-zinc-500">
                    {formatBytes(m.size)}
                  </div>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    update({ provider: "ollama", model: m.name })
                  }
                >
                  Use
                </Button>
              </div>
            ))}
          </div>

          <div className="space-y-2">
            <Label>Pull a model</Label>
            <div className="flex gap-2">
              <Input
                value={pullName}
                onChange={(e) => setPullName(e.target.value)}
                placeholder="e.g. llama3.2-vision:11b  or  hf.co/Qwen/Qwen2.5-VL-7B-Instruct-GGUF"
              />
              <Button
                onClick={() => pullModel(pullName)}
                disabled={pulling || !pullName}
              >
                <Download className="size-4" />
                {pulling ? "Pulling…" : "Pull"}
              </Button>
            </div>
            {pullProgress && (
              <div className="text-xs text-zinc-400 font-mono">
                {pullProgress}
              </div>
            )}
          </div>
        </section>

        {/* HF search */}
        <section className="space-y-4">
          <h2 className="text-xl font-semibold">Hugging Face model search</h2>
          <p className="text-sm text-zinc-400">
            Find a model on the public Hub, then pull it into Ollama by
            referencing it as <code>hf.co/&lt;repo-id&gt;</code>.
          </p>
          <div className="flex gap-2">
            <Input
              value={hfQuery}
              onChange={(e) => setHfQuery(e.target.value)}
              placeholder="search Hugging Face…"
              onKeyDown={(e) => {
                if (e.key === "Enter") searchHf();
              }}
            />
            <Button onClick={searchHf} disabled={hfLoading}>
              <Search className="size-4" />
              {hfLoading ? "Searching…" : "Search"}
            </Button>
          </div>
          <div className="rounded-md border border-zinc-800 bg-zinc-900/40 divide-y divide-zinc-800 max-h-[400px] overflow-y-auto">
            {hfModels.map((m) => (
              <div
                key={m.id}
                className="p-3 flex items-center justify-between text-sm"
              >
                <div className="min-w-0">
                  <div className="font-mono truncate">{m.id}</div>
                  <div className="text-xs text-zinc-500">
                    {m.pipeline_tag ?? "—"} · {m.downloads.toLocaleString()}{" "}
                    downloads · {m.likes.toLocaleString()} likes
                  </div>
                </div>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => pullModel(`hf.co/${m.id}`)}
                  disabled={pulling}
                >
                  <Download className="size-4" />
                  Pull
                </Button>
              </div>
            ))}
            {hfModels.length === 0 && (
              <div className="p-3 text-xs text-zinc-500">
                No results yet — search above.
              </div>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
