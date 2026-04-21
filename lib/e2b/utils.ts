"use server";

import { Sandbox } from "@e2b/desktop";
import { resolution } from "./tool";

/**
 * Optional custom e2b template to launch instead of the default Ubuntu
 * desktop. Set this to the template id printed by `e2b template build` after
 * building the bundled `e2b.Dockerfile` (Kali Linux + XFCE + Kali tooling).
 *
 * If unset, MirXa Kali falls back to the stock e2b desktop image so the app
 * still works out of the box for users who haven't built the template yet.
 */
const TEMPLATE_ID = process.env.E2B_TEMPLATE_ID || undefined;

export const getDesktop = async (id?: string) => {
  try {
    if (id) {
      const connected = await Sandbox.connect(id);
      const isRunning = await connected.isRunning();
      if (isRunning) {
        return connected;
      }
    }

    const desktop = TEMPLATE_ID
      ? await Sandbox.create(TEMPLATE_ID, {
          resolution: [resolution.x, resolution.y],
          timeoutMs: 300000,
        })
      : await Sandbox.create({
          resolution: [resolution.x, resolution.y],
          timeoutMs: 300000,
        });
    await desktop.stream.start();
    return desktop;
  } catch (error) {
    console.error("Error in getDesktop:", error);
    throw error;
  }
};

export const getDesktopURL = async (id?: string) => {
  try {
    const desktop = await getDesktop(id);
    const streamUrl = desktop.stream.getUrl();

    return { streamUrl, id: desktop.sandboxId };
  } catch (error) {
    console.error("Error in getDesktopURL:", error);
    throw error;
  }
};

export const killDesktop = async (id: string = "desktop") => {
  try {
    const desktop = await Sandbox.connect(id);
    await desktop.kill();
    return true;
  } catch (error) {
    console.warn(`Skipping desktop cleanup for ${id}:`, error);
    return false;
  }
};
