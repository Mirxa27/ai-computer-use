import { ArrowUpRight } from "lucide-react";
import { Button } from "./ui/button";

const suggestions = [
  {
    text: "scan a host with nmap",
    prompt:
      "Run `nmap -sV -T4 scanme.nmap.org` in the terminal and summarise the open ports for me.",
  },
  {
    text: "fingerprint a website",
    prompt:
      "Use whatweb to fingerprint https://example.com and tell me what stack it's running.",
  },
  {
    text: "write & run a python script",
    prompt:
      "Open a terminal, write a Python 3 script that prints the first 10 Fibonacci numbers, and run it.",
  },
  {
    text: "open firefox to a url",
    prompt: "Launch Firefox and open https://www.kali.org/tools/ for me.",
  },
];

export const PromptSuggestions = ({
  submitPrompt,
  disabled,
}: {
  submitPrompt: (prompt: string) => void;
  disabled: boolean;
}) => {
  return (
    <div className="flex flex-wrap items-center gap-2 px-4 pb-2">
      {suggestions.map((suggestion, index) => (
        <Button
          key={index}
          variant="outline"
          size="sm"
          onClick={() => submitPrompt(suggestion.prompt)}
          disabled={disabled}
          className="border-zinc-800 bg-zinc-900/60 text-zinc-300 hover:bg-zinc-800 hover:text-zinc-100"
        >
          <span className="text-xs">{suggestion.text}</span>
          <ArrowUpRight className="ml-1 h-3 w-3 text-cyan-400" />
        </Button>
      ))}
    </div>
  );
};
