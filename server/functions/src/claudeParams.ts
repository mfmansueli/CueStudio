import type { BetaMessageStreamParams } from "@anthropic-ai/sdk/resources/beta/messages/messages";
import type { UltraEffort, UltraRequest } from "./ultraRequest";

/** The models the server may be set to write with (`ULTRA_MODEL` in `.env`), and whether each takes Anthropic's refusal fallback. */
export const ultraModels: Readonly<Record<string, { refusalFallback: boolean }>> = {
  "claude-opus-5-5": { refusalFallback: true },
  "claude-sonnet-5-5": { refusalFallback: true },
  // Haiku has no server-side fallback: the parameter is refused for it.
  "claude-haiku-5-5": { refusalFallback: false },
};

/** The most a call may answer, thinking included (Claude's thinking counts against it). A script is 400–700 words. */
export const responseTokens = 32_000;

/** `fallbacks: "default"` re-runs a policy refusal on the model Anthropic recommends for that kind of refusal. */
export const fallbackBeta = "server-side-fallback-2026-07-01";

/**
 * The Claude request for one Ultra AI call: the stage's instructions as the system prompt, its prompt as the one message, its JSON shape as
 * structured output, adaptive thinking at the effort the app asked for or, when it asked for none, the server's (`ULTRA_EFFORT`), streamed.
 */
export function claudeParams(request: UltraRequest, model: string, serverEffort: UltraEffort): BetaMessageStreamParams {
  const fallback = ultraModels[model]?.refusalFallback ?? false;
  return {
    model,
    max_tokens: responseTokens,
    system: request.system,
    messages: [{ role: "user", content: request.prompt }],
    thinking: { type: "adaptive" },
    output_config: {
      effort: request.effort ?? serverEffort,
      ...(request.schema ? { format: { type: "json_schema", schema: request.schema } } : {}),
    },
    ...(fallback ? { fallbacks: "default" as const, betas: [fallbackBeta] } : {}),
  };
}
