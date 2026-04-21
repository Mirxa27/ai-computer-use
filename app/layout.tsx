import type { Metadata } from "next";
import "./globals.css";
import { Toaster } from "@/components/ui/sonner";
import { Analytics } from "@vercel/analytics/react";

export const metadata: Metadata = {
  title: "MirXa Kali — AI Computer Use Agent",
  description:
    "MirXa Kali is a next-generation AI agent that drives a real Kali Linux desktop. Plug in any provider (Anthropic, OpenAI, Google, Groq, Mistral, Ollama, Hugging Face) and any model — even small local ones.",
  applicationName: "MirXa Kali",
  authors: [{ name: "MirXa" }],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className="antialiased font-sans bg-background text-foreground">
        {children}
        <Toaster />
        <Analytics />
      </body>
    </html>
  );
}
