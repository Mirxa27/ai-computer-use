import { tool } from "ai";
import { z } from "zod";
import { getDesktop } from "./utils";
import { resolution } from "./tool";

/**
 * Cross-provider, vision-friendly tool set.
 *
 * Anthropic's `computer_20250124` tools are powerful but only work with
 * Claude. To make MirXa Kali work with *any* provider — including small,
 * locally-hosted models — we expose a flat set of plain JSON tools described
 * with zod schemas. The descriptions are deliberately concrete and short so
 * even small instruction-tuned models can use them reliably.
 *
 * Tool design choices:
 * - One tool per primitive action (click, type, etc.) — simpler for small
 *   models than a single union-typed `computer` tool.
 * - `screenshot` always returns a structured image part so vision models can
 *   see the desktop state.
 * - Coordinates are absolute pixels in a {resolution.x}x{resolution.y} display
 *   — the same as the live stream the user sees.
 */

const wait = (s: number) => new Promise((r) => setTimeout(r, s * 1000));

interface ImageResult {
  type: "image";
  data: string;
  mimeType: string;
}

interface TextResult {
  type: "text";
  text: string;
}

type ToolResult = ImageResult | TextResult;

function img(data: string): ImageResult {
  return { type: "image", data, mimeType: "image/png" };
}

function txt(text: string): TextResult {
  return { type: "text", text };
}

/** Convert a tool result into the AI SDK ToolResultContent shape. */
function toContent(result: ToolResult) {
  if (result.type === "image") {
    return [{ type: "image" as const, data: result.data, mimeType: result.mimeType }];
  }
  return [{ type: "text" as const, text: result.text }];
}

export function genericTools(sandboxId: string) {
  const screenshot = tool({
    description:
      `Take a screenshot of the Kali Linux desktop (${resolution.x}x${resolution.y}). ` +
      `Always call this first when starting a task and after any action whose visual ` +
      `result you need to verify.`,
    parameters: z.object({}).strict(),
    execute: async (): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      const image = await desktop.screenshot();
      return img(Buffer.from(image).toString("base64"));
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const click = tool({
    description:
      "Click the mouse at the given absolute pixel coordinates on the desktop. " +
      "Use button=\"left\" (default), \"right\", or \"middle\". " +
      "Set double=true for a double click.",
    parameters: z
      .object({
        x: z.number().int().min(0).max(resolution.x),
        y: z.number().int().min(0).max(resolution.y),
        button: z.enum(["left", "right", "middle"]).optional().default("left"),
        double: z.boolean().optional().default(false),
      })
      .strict(),
    execute: async ({ x, y, button, double }): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      await desktop.moveMouse(x, y);
      if (double) {
        await desktop.doubleClick();
      } else if (button === "right") {
        await desktop.rightClick();
      } else if (button === "middle") {
        await desktop.middleClick();
      } else {
        await desktop.leftClick();
      }
      return txt(`${double ? "Double-" : ""}${button} clicked at ${x},${y}`);
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const type_ = tool({
    description:
      "Type the given UTF-8 text at the current cursor focus. Use this for " +
      "typing into focused text fields. Does NOT press Enter — use the `key` " +
      "tool with \"enter\" if you need to submit.",
    parameters: z.object({ text: z.string().min(1) }).strict(),
    execute: async ({ text }): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      await desktop.write(text);
      return txt(`Typed ${text.length} character(s)`);
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const key = tool({
    description:
      'Press a single key or chord using xdotool syntax (e.g. "enter", ' +
      '"escape", "ctrl+l", "alt+Tab", "Page_Down").',
    parameters: z.object({ key: z.string().min(1) }).strict(),
    execute: async ({ key: k }): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      const normalized = k.toLowerCase() === "return" ? "enter" : k;
      await desktop.press(normalized);
      return txt(`Pressed ${k}`);
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const scroll = tool({
    description: "Scroll the page in the given direction by `amount` clicks.",
    parameters: z
      .object({
        direction: z.enum(["up", "down", "left", "right"]),
        amount: z.number().int().min(1).max(20).default(3),
      })
      .strict(),
    execute: async ({ direction, amount }): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      // The e2b SDK only exposes vertical scrolling at the time of writing;
      // emulate horizontal with arrow keys.
      if (direction === "up" || direction === "down") {
        await desktop.scroll(direction, amount);
      } else {
        const arrow = direction === "left" ? "Left" : "Right";
        for (let i = 0; i < amount; i++) await desktop.press(arrow);
      }
      return txt(`Scrolled ${direction} by ${amount}`);
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const drag = tool({
    description:
      "Click-and-drag from one absolute coordinate to another (left mouse button).",
    parameters: z
      .object({
        from: z.object({
          x: z.number().int().min(0).max(resolution.x),
          y: z.number().int().min(0).max(resolution.y),
        }),
        to: z.object({
          x: z.number().int().min(0).max(resolution.x),
          y: z.number().int().min(0).max(resolution.y),
        }),
      })
      .strict(),
    execute: async ({ from, to }): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      await desktop.drag([from.x, from.y], [to.x, to.y]);
      return txt(`Dragged ${from.x},${from.y} -> ${to.x},${to.y}`);
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const waitTool = tool({
    description: "Wait the given number of seconds (max 5) for the UI to settle.",
    parameters: z
      .object({ seconds: z.number().min(0.1).max(5) })
      .strict(),
    execute: async ({ seconds }): Promise<ToolResult> => {
      await wait(seconds);
      return txt(`Waited ${seconds}s`);
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  const bash = tool({
    description:
      "Run a shell command inside the Kali Linux sandbox and return its stdout " +
      "(stderr is appended on non-zero exit). Prefer this over GUI clicks for " +
      "anything scriptable: package install (`sudo apt-get install -y ...`), " +
      "file ops, recon tools (`nmap`, `whatweb`, `nikto`), git, curl, etc.",
    parameters: z
      .object({
        command: z.string().min(1),
        timeoutSeconds: z.number().int().min(1).max(600).optional().default(120),
      })
      .strict(),
    execute: async ({ command, timeoutSeconds }): Promise<ToolResult> => {
      const desktop = await getDesktop(sandboxId);
      try {
        const result = await desktop.commands.run(command, {
          timeoutMs: timeoutSeconds * 1000,
        });
        const out = result.stdout?.trim() || "";
        const err = result.stderr?.trim() || "";
        const exit = result.exitCode ?? 0;
        if (exit !== 0) return txt(`exit=${exit}\n${out}\n--stderr--\n${err}`.trim());
        return txt(out || "(no output)");
      } catch (e) {
        return txt(`Error: ${e instanceof Error ? e.message : String(e)}`);
      }
    },
    experimental_toToolResultContent: (r) => toContent(r as ToolResult),
  });

  return {
    screenshot,
    click,
    type: type_,
    key,
    scroll,
    drag,
    wait: waitTool,
    bash,
  };
}
