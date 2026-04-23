/**
 * Shared URL hardening helpers used to validate any URL that originates from
 * an untrusted client (request body, request header, etc.) before the server
 * uses it to make an outbound HTTP request.
 *
 * Goals:
 * - Reject anything that is not http(s).
 * - When `requirePrivate` is true, reject anything that is not loopback or
 *   RFC1918. This blocks SSRF against arbitrary internet hosts and cloud
 *   instance metadata services (`169.254.169.254` etc.).
 * - When `allowedHosts` is provided, only allow URLs whose hostname matches
 *   one of those entries (suffix match for `.example.com` style entries).
 */

export function stripTrailingSlashes(s: string): string {
  // Manual scan instead of /\/+$/ to avoid backtracking-regex ReDoS on
  // pathological inputs.
  let end = s.length;
  while (end > 0 && s.charCodeAt(end - 1) === 47 /* '/' */) end--;
  return s.slice(0, end);
}

export function isPrivateOrLoopbackHost(hostname: string): boolean {
  const h = hostname.toLowerCase();
  if (h === "localhost" || h.endsWith(".localhost")) return true;
  // IPv6 loopback only — explicitly NOT link-local (would expose
  // metadata endpoints like fe80::a9fe:a9fe).
  if (h === "::1" || h === "[::1]") return true;
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(h);
  if (!m) return false;
  const [a, b] = [Number(m[1]), Number(m[2])];
  if ([a, b].some((n) => Number.isNaN(n) || n < 0 || n > 255)) return false;
  if (a === 127) return true; // 127.0.0.0/8 (loopback)
  if (a === 10) return true; // 10.0.0.0/8 (RFC1918)
  if (a === 192 && b === 168) return true; // 192.168.0.0/16 (RFC1918)
  if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12 (RFC1918)
  // Deliberately exclude 169.254.0.0/16 (cloud metadata).
  return false;
}

export interface SafeUrlOptions {
  /** Require the host to be loopback or an RFC1918 private address. */
  requirePrivate?: boolean;
  /** If provided, the host must equal one of these (or end with `.<entry>`). */
  allowedHosts?: readonly string[];
}

function hostMatches(hostname: string, allowed: readonly string[]): boolean {
  const h = hostname.toLowerCase();
  return allowed.some((entry) => {
    const e = entry.toLowerCase();
    return h === e || h.endsWith(`.${e}`);
  });
}

/**
 * Returns the parsed URL if it passes the requested checks, otherwise null.
 * Caller is responsible for constructing the final fetch URL — this function
 * only validates, it does not modify the input string.
 */
export function safeParseUrl(
  raw: string | null | undefined,
  opts: SafeUrlOptions = {},
): URL | null {
  if (!raw) return null;
  let parsed: URL;
  try {
    parsed = new URL(raw.trim());
  } catch {
    return null;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;

  if (opts.requirePrivate && !isPrivateOrLoopbackHost(parsed.hostname)) {
    return null;
  }
  if (opts.allowedHosts && !hostMatches(parsed.hostname, opts.allowedHosts)) {
    return null;
  }
  return parsed;
}
