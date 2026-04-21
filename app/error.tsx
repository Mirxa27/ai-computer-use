"use client";

import Link from "next/link";
import { useEffect } from "react";
import { AlertTriangle, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-50 flex items-center justify-center px-6">
      <div className="w-full max-w-lg rounded-2xl border border-zinc-800 bg-zinc-900/70 p-8 shadow-2xl">
        <div className="flex items-center gap-3 text-amber-400">
          <AlertTriangle className="size-6" />
          <span className="text-sm font-medium uppercase tracking-[0.2em]">
            Runtime error
          </span>
        </div>
        <h1 className="mt-4 text-2xl font-semibold">Something went wrong.</h1>
        <p className="mt-3 text-sm text-zinc-400">
          The desktop session is still isolated, but this page hit an unexpected
          error. Retry the route or go back home to start a fresh session.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Button onClick={reset}>
            <RefreshCw className="size-4" />
            Try again
          </Button>
          <Button asChild variant="outline">
            <Link href="/">Return home</Link>
          </Button>
        </div>
      </div>
    </div>
  );
}
