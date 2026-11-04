/**
 * The HTTP status the app hears when Claude's request fails before the first word, read the way the app reads it
 * (`ClaudeStream.failure(status:)`: 401/403/429 "rejected", 408/504 "timed out", anything else "provider"). The API's message never goes
 * back: it can quote the request.
 */
export interface FailureKind {
  status: number;
  /** For the server's log only. */
  kind: string;
}

export function failureKind(error: unknown): FailureKind {
  const status = typeof error === "object" && error !== null ? (error as { status?: unknown }).status : undefined;
  const message = error instanceof Error ? error.message.toLowerCase() : "";
  if (typeof status !== "number") {
    if (message.includes("timed out") || message.includes("timeout")) return { status: 504, kind: "timeout" };
    return { status: 502, kind: "network" };
  }
  // No credits left on Anthropic's side is the owner's to fix (Console › Billing), never the creator's.
  if (status === 400 && message.includes("credit balance")) return { status: 503, kind: "credits" };
  if (status === 401 || status === 403) return { status: 503, kind: "key" };
  if (status === 429) return { status: 429, kind: "rate" };
  if (status === 408 || status === 504) return { status: 504, kind: "timeout" };
  if (status === 529 || status >= 500) return { status: 503, kind: "overloaded" };
  return { status: 502, kind: `api${status}` };
}
