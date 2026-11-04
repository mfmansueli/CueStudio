import assert from "node:assert/strict";
import { test } from "node:test";
import { failureKind } from "../appStatus";
import { claudeParams, fallbackBeta, responseTokens } from "../claudeParams";
import { parseUltraRequest, requestLimits } from "../ultraRequest";

const schema = {
  type: "object",
  properties: { script: { type: "string" } },
  required: ["script"],
  additionalProperties: false,
};
const draft = { stage: "draft", system: "You write scripts.", prompt: "An idea", effort: null, schema: null };
const fit = { stage: "fit", system: "You fit scripts.", prompt: "A script", effort: "medium", schema };

test("a draft and a JSON stage are accepted as sent", () => {
  assert.deepEqual(parseUltraRequest(draft), { ok: true, request: draft });
  assert.deepEqual(parseUltraRequest(fit), { ok: true, request: fit });
});

test("a missing schema reads as the draft's none, a missing effort as the server's", () => {
  assert.deepEqual(parseUltraRequest({ stage: "draft", system: "You write scripts.", prompt: "An idea" }), { ok: true, request: draft });
});

test("anything the app never sends is refused, by kind only", () => {
  const cases: [unknown, string][] = [
    [null, "body"],
    [[draft], "body"],
    [{ ...draft, stage: "ideas" }, "stage"],
    [{ ...draft, effort: "max" }, "effort"],
    [{ ...draft, system: "  " }, "system"],
    [{ ...draft, prompt: 7 }, "prompt"],
    [{ ...draft, prompt: "x".repeat(requestLimits.promptCharacters + 1) }, "prompt"],
    [{ ...draft, system: "x".repeat(requestLimits.systemCharacters + 1) }, "system"],
    [{ ...draft, schema }, "schema"],
    [{ ...fit, schema: null }, "schema"],
    [{ ...fit, schema: { type: "array" } }, "schema"],
    [{ ...fit, schema: { type: "object", description: "x".repeat(requestLimits.schemaCharacters) } }, "schema"],
  ];
  for (const [body, reason] of cases) assert.deepEqual(parseUltraRequest(body), { ok: false, reason });
});

test("Sonnet and Opus ask for Anthropic's refusal fallback, Haiku doesn't", () => {
  const request = parseUltraRequest(fit);
  assert.ok(request.ok);
  const sonnet = claudeParams(request.request, "claude-sonnet-5-5", "high");
  assert.equal(sonnet.fallbacks, "default");
  assert.deepEqual(sonnet.betas, [fallbackBeta]);
  assert.equal(claudeParams(request.request, "claude-opus-5-5", "high").fallbacks, "default");
  const haiku = claudeParams(request.request, "claude-haiku-5-5", "high");
  assert.equal(haiku.fallbacks, undefined);
  assert.equal(haiku.betas, undefined);
});

test("the request carries the stage's words, effort and shape, with the server's ceiling", () => {
  const request = parseUltraRequest(fit);
  assert.ok(request.ok);
  const params = claudeParams(request.request, "claude-sonnet-5-5", "high");
  assert.equal(params.model, "claude-sonnet-5-5");
  assert.equal(params.max_tokens, responseTokens);
  assert.equal(params.system, fit.system);
  assert.deepEqual(params.messages, [{ role: "user", content: fit.prompt }]);
  assert.deepEqual(params.thinking, { type: "adaptive" });
  assert.deepEqual(params.output_config, { effort: "medium", format: { type: "json_schema", schema } });
});

test("the draft asks for no JSON shape, at the server's effort when the app asks for none", () => {
  const request = parseUltraRequest(draft);
  assert.ok(request.ok);
  assert.deepEqual(claudeParams(request.request, "claude-sonnet-5-5", "high").output_config, { effort: "high" });
  assert.deepEqual(claudeParams(request.request, "claude-opus-5-5", "medium").output_config, { effort: "medium" });
});

test("a failure reaches the app as the status it reads, never the API's message", () => {
  const api = (status: number, message = "") => Object.assign(new Error(message), { status });
  assert.deepEqual(failureKind(api(429)), { status: 429, kind: "rate" });
  assert.deepEqual(failureKind(api(401)), { status: 503, kind: "key" });
  assert.deepEqual(failureKind(api(400, "Your credit balance is too low to access the Anthropic API.")), { status: 503, kind: "credits" });
  assert.deepEqual(failureKind(api(529)), { status: 503, kind: "overloaded" });
  assert.deepEqual(failureKind(api(500)), { status: 503, kind: "overloaded" });
  assert.deepEqual(failureKind(api(504)), { status: 504, kind: "timeout" });
  assert.deepEqual(failureKind(api(400, "invalid schema")), { status: 502, kind: "api400" });
  assert.deepEqual(failureKind(new Error("Request timed out.")), { status: 504, kind: "timeout" });
  assert.deepEqual(failureKind(new Error("socket hang up")), { status: 502, kind: "network" });
});
