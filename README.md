# MirXa Kali

> A next-generation AI agent that drives a real **Kali Linux** desktop. Plug in
> any provider — Anthropic, OpenAI, Google Gemini, Groq, Mistral, OpenRouter,
> a local Ollama server, or any model from Hugging Face — and let it click,
> type, and run shell commands on your behalf.

![MirXa Kali](public/opengraph-image.png)

## What's inside

- **Real Kali Linux desktop** — a custom [`e2b.Dockerfile`](./e2b.Dockerfile)
  builds an XFCE-based `kali-rolling` image with the standard Kali tooling
  (`nmap`, `whatweb`, `nikto`, `sqlmap`, `hydra`, `gobuster`, …) preinstalled.
- **Multi-provider AI SDK** — Anthropic Claude (computer-use), OpenAI,
  Google Gemini, Groq, Mistral, OpenRouter, Ollama, and the Hugging Face
  Inference Router are all first-class. Per-request API keys.
- **Small-model friendly** — non-Anthropic and small models use a compact,
  cross-provider tool set (`screenshot`, `click`, `type`, `key`, `scroll`,
  `drag`, `wait`, `bash`) defined with strict zod schemas, so even a 7B local
  vision model can drive the desktop.
- **Local model manager** — search Hugging Face from the **Settings** page and
  pull any GGUF model into your local Ollama with one click
  (`hf.co/<repo>` shorthand). Your HF token is forwarded for gated models.
- **Settings page** at `/settings` — provider, model, API keys, base URLs,
  custom instructions, temperature, max steps. Everything is stored in your
  browser; nothing is persisted server-side.
- **Session controls** — export the live transcript as JSON, clear the current
  chat, and rotate into a brand-new desktop session without refreshing.
- **Modern dark UI** — Kali-themed accents, live model badge in the chat
  header, advanced view of every tool call.

## Getting started

### 1. Install

```bash
npm install
```

### 2. Configure

Copy `.env.example` to `.env.local` and fill in the keys you want to use on the
server. Anything you leave blank can still be entered per-session from the
**Settings** page.

```env
E2B_API_KEY=...                # required
E2B_TEMPLATE_ID=               # optional — set to your built Kali template id

# Any of these are optional; users can also paste their own from /settings.
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_GENERATIVE_AI_API_KEY=
GROQ_API_KEY=
MISTRAL_API_KEY=
OPENROUTER_API_KEY=
HF_TOKEN=
```

### 3. Build the Kali e2b template (recommended)

```bash
npm i -g @e2b/cli
e2b auth login
e2b template build --name mirxa-kali       # uses ./e2b.Dockerfile + ./e2b.toml
```

The CLI prints a template id — put it in `.env.local` as `E2B_TEMPLATE_ID`.
Without this, the app still runs but on the stock e2b Ubuntu desktop.

### 4. Run

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000), then visit `/settings` to
choose your provider and model.

## One-command Docker startup

MirXa Kali now includes a production Docker image, a health endpoint, and a
Compose stack for quick local startup.

### App only

```bash
cp .env.example .env
docker compose up --build
```

### App + local Ollama

```bash
cp .env.example .env
docker compose --profile ollama up --build
```

This starts:

- `app` on [http://localhost:3000](http://localhost:3000)
- optional `ollama` on `http://localhost:11434`
- a health check at `/api/health`

For Docker-based Ollama, the compose file defaults
`NEXT_PUBLIC_DEFAULT_OLLAMA_URL` to `http://ollama:11434` so the app container
can reach the bundled Ollama service.

## Using local Hugging Face models

1. Install [Ollama](https://ollama.com/) and start it (`ollama serve`).
2. In **Settings → Local models**, enter your Ollama URL (defaults to
   `http://localhost:11434`).
3. Search Hugging Face from the same page and click **Pull** on any model —
   MirXa Kali asks Ollama to download it as `hf.co/<repo>`.
4. Switch the active provider to **Ollama (local)** and select the model.

That's it — the agent will use the cross-provider tool set, so even small 7B
vision models (Qwen 2.5 VL, LLaVA, Llama 3.2 Vision) can drive the desktop.

## Project layout

```
app/
  api/
    chat/route.ts            # multi-provider streaming endpoint
    health/route.ts          # container / orchestrator health check
    kill-desktop/            # graceful sandbox teardown
    models/
      huggingface/           # HF Hub model search proxy
      ollama/                # list / pull local models (HF GGUF supported)
  page.tsx                   # chat + desktop stream
  settings/page.tsx          # provider, model & local-model manager
lib/
  agent-prompt.ts            # Kali-aware system prompt
  model-factory.ts           # provider -> LanguageModelV1
  providers.ts               # provider/model registry
  runtime-config.ts          # public runtime defaults
  settings.ts                # client-side settings + localStorage
  e2b/
    tool.ts                  # Anthropic computer-use tools
    generic-tools.ts         # cross-provider screenshot/click/type/... tools
    utils.ts                 # sandbox lifecycle (uses E2B_TEMPLATE_ID)
Dockerfile                   # production Next.js container image
docker-compose.yml           # one-command app / Ollama startup
e2b.Dockerfile               # Kali Linux + XFCE desktop template
e2b.toml                     # e2b template config
```

## License

MIT.
