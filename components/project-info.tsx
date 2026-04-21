import { motion } from "motion/react";
import Link from "next/link";
import { Settings, Terminal, Cpu, Brain } from "lucide-react";

export const ProjectInfo = () => {
  return (
    <motion.div className="w-full px-2 space-y-4">
      <div className="rounded-xl border border-zinc-800 bg-gradient-to-b from-zinc-900/80 to-zinc-950/80 p-6 flex flex-col gap-3">
        <div className="flex items-center gap-2 text-cyan-400 text-sm font-mono">
          <Terminal className="size-4" />
          <span>root@mirxa-kali:~#</span>
        </div>
        <h3 className="text-2xl font-bold tracking-tight text-zinc-50">
          MirXa Kali
        </h3>
        <p className="text-sm text-zinc-400 leading-relaxed">
          A next-generation AI agent that drives a real{" "}
          <span className="text-cyan-400">Kali Linux</span> desktop. It can
          click, type, run shell commands, and use the standard Kali tooling to
          help you get work done — with{" "}
          <span className="text-emerald-400">any model</span> from any provider.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 pt-2">
          <Feature icon={<Brain className="size-4" />} label="Multi-provider" />
          <Feature icon={<Cpu className="size-4" />} label="Local Hugging Face models" />
          <Feature icon={<Settings className="size-4" />} label="Fully configurable" />
        </div>
        <div className="pt-2">
          <Link
            href="/settings"
            className="text-cyan-400 hover:text-cyan-300 text-sm inline-flex items-center gap-1"
          >
            <Settings className="size-3.5" /> Configure provider, model & local downloads →
          </Link>
        </div>
      </div>
    </motion.div>
  );
};

const Feature = ({
  icon,
  label,
}: {
  icon: React.ReactNode;
  label: string;
}) => (
  <div className="flex items-center gap-2 rounded-md border border-zinc-800 bg-zinc-950/50 px-3 py-2 text-xs text-zinc-300">
    <span className="text-cyan-400">{icon}</span>
    <span>{label}</span>
  </div>
);

/**
 * Compact link to the settings page, shown in the chat header where the old
 * Vercel "Deploy" button used to be. Keeping the export name avoids touching
 * page.tsx layout.
 */
export const DeployButton = () => {
  return (
    <Link
      href="/settings"
      className="flex flex-row gap-2 items-center bg-zinc-900 border border-zinc-800 px-3 py-1.5 rounded-md text-zinc-200 hover:bg-zinc-800 text-sm"
    >
      <Settings className="size-3.5" />
      Settings
    </Link>
  );
};
