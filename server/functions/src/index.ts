import Anthropic from "@anthropic-ai/sdk";
import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { getFirestore } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import { defineSecret, defineString } from "firebase-functions/params";
import { failureKind } from "./appStatus";
import { claudeParams, ultraModels } from "./claudeParams";
import { firestoreReferralStore } from "./firestoreReferralStore";
import { firestoreSpendLedger, firestoreUltraStore } from "./firestoreUltraStore";
import { parseReferralRequest } from "./referralRequest";
import { activate, redeem, status } from "./referralRules";
import { appleProVerifier, type ProVerifier } from "./storeProof";
import { parseUltraIdentity } from "./ultraIdentity";
import { admit, allowance, settle, type CallContext, type ProProof, type Refusal } from "./ultraMetering";
import { cost, dailyBudget, dayKey, meteringMode } from "./ultraPolicy";
import { efforts, parseUltraRequest, type UltraEffort } from "./ultraRequest";

initializeApp();

/** The Claude API key, in Secret Manager (`firebase functions:secrets:set ANTHROPIC_API_KEY`): never in the app, the repo or a log. */
const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
/** Who writes (`.env`): changing it is a redeploy, never a new app build. */
const ultraModel = defineString("ULTRA_MODEL", { default: "claude-sonnet-5-5" });
/** How hard it thinks when the app leaves it to the server (`.env`): low, medium or high. */
const ultraEffort = defineString("ULTRA_EFFORT", { default: "high" });
/** How the server meters Ultra AI (`ultraPolicy`): off, observe or enforce. */
const ultraMeteringMode = defineString("ULTRA_METERING", { default: "observe" });
/** What Cue may spend on Claude in a UTC day, in USD; past it Ultra AI rests until the next day. 0 is no budget. */
const ultraDailyBudget = defineString("ULTRA_DAILY_BUDGET_USD", { default: "20" });

let proVerifier: ProVerifier | undefined;
/** Apple's signature checks, made once per instance. */
function verifier(): ProVerifier {
  proVerifier ??= appleProVerifier();
  return proVerifier;
}

/** A verified Cue Pro from the app's signed transaction, or null (none sent, not Apple's, expired, refunded). */
async function verifiedPro(proof: string | null, now: number): Promise<ProProof | null> {
  if (!proof) return null;
  try {
    return await verifier().verify(proof, now);
  } catch {
    return null;
  }
}

/** The status the app reads for each refusal, and the reason in `X-Ultra-Refusal` (older builds read the status alone). */
const refusalStatus: Record<Refusal | "paused", number> = { noCredits: 402, limited: 429, script: 409, identity: 426, paused: 503 };

function refuse(res: { status(code: number): { setHeader(name: string, value: string): { end(): void } } }, reason: Refusal | "paused") {
  res.status(refusalStatus[reason]).setHeader("X-Ultra-Refusal", reason).end();
}

/**
 * Ultra AI's one call to Claude. The app sends the stage's instructions, prompt, effort and JSON shape with a Firebase App Check token
 * (App Attest on a real iPhone; a registered debug token in a Debug build); the server checks the token, adds the key, the model and the
 * limits, and streams Claude's events back as they arrive (server-sent events, the Claude API's own shape), so the app reads them as it read
 * the API in the lab. A creator who stops the script closes the connection, and the server stops Claude with it. The log keeps the stage,
 * the model, token counts, cost, time and how it ended: never the idea, the voice or the script.
 *
 * Metering (`ULTRA_METERING`, `ultraMetering`): the app also sends the install's id, the run's id and, on Pro, the App Store's signed
 * transaction. The server holds a credit at the draft and spends it when the polish arrives, refuses past Cue's daily budget, and, when
 * enforcing, past the creator's scripts or the hourly ceiling. `{"action": "allowance"}` answers what the creator has left.
 */
export const ultra = onRequest(
  {
    region: "us-central1",
    secrets: [anthropicKey],
    timeoutSeconds: 300,
    memory: "256MiB",
    maxInstances: 10,
    concurrency: 40,
    invoker: "public",
  },
  async (req, res) => {
    const started = Date.now();
    if (req.method !== "POST") {
      res.status(405).end();
      return;
    }
    const token = req.header("X-Firebase-AppCheck");
    if (!token) {
      logger.warn("ultra_refused", { reason: "appcheck_missing" });
      res.status(401).end();
      return;
    }
    let appId: string;
    try {
      appId = (await getAppCheck().verifyToken(token)).appId;
    } catch {
      logger.warn("ultra_refused", { reason: "appcheck_invalid" });
      res.status(401).end();
      return;
    }
    const mode = meteringMode(ultraMeteringMode.value());
    const identityParsed = parseUltraIdentity(req.body);
    if (!identityParsed.ok) {
      logger.warn("ultra_refused", { reason: identityParsed.reason, appId });
      res.status(400).end();
      return;
    }
    const { identity } = identityParsed;
    const now = Date.now();
    const db = getFirestore();
    const store = firestoreUltraStore(db);
    const ledger = firestoreSpendLedger(db);
    const budget = dailyBudget(ultraDailyBudget.value());
    const day = dayKey(now);

    if ((req.body as Record<string, unknown>).action === "allowance") {
      if (mode === "off" || !identity.installId) {
        res.status(200).json({ metering: "off" });
        return;
      }
      try {
        const pro = await verifiedPro(identity.proof, now);
        const paused = budget > 0 && (await ledger.spent(day)) >= budget;
        res.status(200).json({ metering: mode, paused, ...(await allowance(store, identity.installId, pro, now)) });
      } catch (error) {
        logger.error("ultra_allowance_failed", { error: error instanceof Error ? error.message : "unknown" });
        res.status(503).end();
      }
      return;
    }

    const parsed = parseUltraRequest(req.body);
    if (!parsed.ok) {
      logger.warn("ultra_refused", { reason: parsed.reason, appId });
      res.status(400).end();
      return;
    }
    const model = ultraModel.value();
    const effort = ultraEffort.value() as UltraEffort;
    if (!ultraModels[model] || !efforts.includes(effort)) {
      logger.error("ultra_misconfigured", { model, effort });
      res.status(503).end();
      return;
    }

    const { request } = parsed;
    let context: CallContext | null = null;
    if (mode !== "off") {
      try {
        if (budget > 0 && (await ledger.spent(day)) >= budget) {
          logger.warn("ultra_refused", { reason: "paused", stage: request.stage, appId });
          refuse(res, "paused");
          return;
        }
        if (!identity.installId) {
          if (mode === "enforce") {
            logger.warn("ultra_refused", { reason: "identity", stage: request.stage, appId });
            refuse(res, "identity");
            return;
          }
        } else {
          const candidate: CallContext = {
            installId: identity.installId, scriptId: identity.scriptId, stage: request.stage, pro: await verifiedPro(identity.proof, now),
          };
          const admission = await admit(store, candidate, now);
          if (admission.ok) {
            context = candidate;
          } else if (mode === "enforce") {
            logger.warn("ultra_refused", { reason: admission.refusal, stage: request.stage, appId });
            refuse(res, admission.refusal);
            return;
          } else {
            logger.info("ultra_would_refuse", { reason: admission.refusal, stage: request.stage, appId });
          }
        }
      } catch (error) {
        logger.error("ultra_metering_failed", { stage: request.stage, error: error instanceof Error ? error.message : "unknown" });
        if (mode === "enforce") {
          res.status(503).end();
          return;
        }
      }
    }
    /** After the call: the script's credit spent or given back, and what the call cost added to the day. */
    const account = async (finished: boolean, spent: number) => {
      if (mode === "off") return;
      try {
        if (context) await settle(store, context, finished, Date.now());
        if (spent > 0) await ledger.add(day, spent);
      } catch (error) {
        logger.error("ultra_metering_failed", { stage: request.stage, error: error instanceof Error ? error.message : "unknown" });
      }
    };

    const client = new Anthropic({ apiKey: anthropicKey.value(), maxRetries: 1, timeout: 280_000 });
    const stream = client.beta.messages.stream(claudeParams(request, model, effort));
    let closedByApp = false;
    res.on("close", () => {
      if (!res.writableEnded) {
        closedByApp = true;
        stream.abort();
      }
    });

    const usage = { model, input: 0, cacheRead: 0, cacheWrite: 0, output: 0 };
    let stopReason: string | null = null;
    let headersSent = false;
    try {
      for await (const event of stream) {
        if (!headersSent) {
          res.status(200);
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.flushHeaders();
          headersSent = true;
        }
        if (event.type === "message_start") {
          usage.model = event.message.model;
          usage.input = event.message.usage.input_tokens;
          usage.cacheRead = event.message.usage.cache_read_input_tokens ?? 0;
          usage.cacheWrite = event.message.usage.cache_creation_input_tokens ?? 0;
        } else if (event.type === "message_delta") {
          stopReason = event.delta.stop_reason ?? stopReason;
          usage.output = event.usage.output_tokens;
        }
        res.write(`event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`);
      }
      const spent = cost(usage);
      logger.info("ultra_call", {
        stage: request.stage, effort: request.effort ?? effort, ...usage, usd: spent, stopReason, ms: Date.now() - started, appId,
      });
      // Counted before the answer ends: Cloud Functions may stop the instance's CPU once the response is sent.
      await account(stopReason === "end_turn", spent);
      res.end();
    } catch (error) {
      const spent = cost(usage);
      await account(false, spent);
      if (closedByApp) {
        logger.info("ultra_stopped", { stage: request.stage, ...usage, usd: spent, ms: Date.now() - started, appId });
        return;
      }
      const failure = failureKind(error);
      const log = failure.kind === "credits" || failure.kind === "key" ? logger.error : logger.warn;
      log("ultra_failed", { stage: request.stage, kind: failure.kind, ...usage, ms: Date.now() - started, appId });
      if (headersSent) {
        res.write(`event: error\ndata: ${JSON.stringify({ type: "error", error: { type: failure.kind } })}\n\n`);
        res.end();
      } else {
        res.status(failure.status).end();
      }
    }
  },
);

/**
 * Cue's invites (`referralRules`): "status" gives the creator their code and how many friends joined and exported, "redeem" records the code
 * a friend typed, "activate" counts that friend's first export for the creator who invited them. App Check proves each request comes from Cue;
 * the body carries only the install's random id (and the typed code). The log keeps the step and how it ended, never a code or an id.
 */
export const referral = onRequest(
  { region: "us-central1", timeoutSeconds: 20, memory: "256MiB", maxInstances: 5, concurrency: 40, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).end();
      return;
    }
    const token = req.header("X-Firebase-AppCheck");
    if (!token) {
      logger.warn("referral_refused", { reason: "appcheck_missing" });
      res.status(401).end();
      return;
    }
    try {
      await getAppCheck().verifyToken(token);
    } catch {
      logger.warn("referral_refused", { reason: "appcheck_invalid" });
      res.status(401).end();
      return;
    }
    const parsed = parseReferralRequest(req.body);
    if (!parsed.ok) {
      logger.warn("referral_refused", { reason: parsed.reason });
      res.status(400).end();
      return;
    }
    const { action, installId, code, proof } = parsed.request;
    const store = firestoreReferralStore(getFirestore());
    const now = Date.now();
    try {
      if (action === "status") {
        // Friends rewarded since last time are credited as Ultra AI scripts only on a Cue Pro the server verified.
        const isPro = (await verifiedPro(proof, now)) !== null;
        res.status(200).json(await status(store, installId, now, undefined, isPro));
      } else if (action === "redeem") {
        const outcome = await redeem(store, installId, code ?? "", now);
        logger.info("referral_redeem", { outcome });
        res.status(200).json({ outcome });
      } else {
        const outcome = await activate(store, installId, now);
        logger.info("referral_activate", { outcome });
        res.status(200).json({ outcome });
      }
    } catch (error) {
      logger.error("referral_failed", { action, error: error instanceof Error ? error.message : "unknown" });
      res.status(503).end();
    }
  },
);

