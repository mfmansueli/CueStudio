/**
 * What the app sends for one Ultra AI call (`CueServerUltraClient` in the app): the stage, the stage's instructions and prompt exactly as
 * "What Cue sends" shows them, how hard the model should think, and the JSON shape the stage answers in. The server adds everything that must
 * not live in the app: the key, the model, the token ceiling and the refusal fallback.
 */
export type UltraStage = "draft" | "check" | "review" | "fit";

export type UltraEffort = "low" | "medium" | "high";

export interface UltraRequest {
  stage: UltraStage;
  system: string;
  prompt: string;
  /** A lower effort the app asks for on purpose (the lab's comparisons); null leaves it to the server's `ULTRA_EFFORT`. */
  effort: UltraEffort | null;
  /** The stage's JSON schema (structured outputs); null for the draft, which is plain speech. */
  schema: Record<string, unknown> | null;
}

export type ParsedUltraRequest = { ok: true; request: UltraRequest } | { ok: false; reason: string };

/**
 * Ceilings well above a real request (a script's instructions and prompt run 3,000–5,000 tokens together), so a request that passes App
 * Check still can't turn the server into a general-purpose Claude endpoint with huge prompts.
 */
export const requestLimits = {
  systemCharacters: 40_000,
  promptCharacters: 40_000,
  schemaCharacters: 4_000,
};

const stages: readonly UltraStage[] = ["draft", "check", "review", "fit"];
export const efforts: readonly UltraEffort[] = ["low", "medium", "high"];

/** The request, or why it was refused (a kind only: the reason never quotes the text). */
export function parseUltraRequest(body: unknown): ParsedUltraRequest {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { ok: false, reason: "body" };
  const fields = body as Record<string, unknown>;
  const stage = fields.stage;
  if (typeof stage !== "string" || !stages.includes(stage as UltraStage)) return { ok: false, reason: "stage" };
  const effort = fields.effort ?? null;
  if (effort !== null && (typeof effort !== "string" || !efforts.includes(effort as UltraEffort))) return { ok: false, reason: "effort" };
  const system = fields.system;
  if (typeof system !== "string" || system.trim() === "" || system.length > requestLimits.systemCharacters) {
    return { ok: false, reason: "system" };
  }
  const prompt = fields.prompt;
  if (typeof prompt !== "string" || prompt.trim() === "" || prompt.length > requestLimits.promptCharacters) {
    return { ok: false, reason: "prompt" };
  }
  const schema = fields.schema ?? null;
  if (schema !== null) {
    if (typeof schema !== "object" || Array.isArray(schema)) return { ok: false, reason: "schema" };
    const shape = schema as Record<string, unknown>;
    if (shape.type !== "object" || JSON.stringify(shape).length > requestLimits.schemaCharacters) return { ok: false, reason: "schema" };
  }
  // The draft is plain speech; every other stage answers in JSON.
  if ((stage === "draft") !== (schema === null)) return { ok: false, reason: "schema" };
  return {
    ok: true,
    request: {
      stage: stage as UltraStage,
      system,
      prompt,
      effort: effort as UltraEffort | null,
      schema: schema as Record<string, unknown> | null,
    },
  };
}
