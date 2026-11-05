import assert from "node:assert/strict";
import { test } from "node:test";
import type { InstallRecord } from "../referralRules";
import { appleProVerifier, appleRoots, proFrom } from "../storeProof";
import { parseUltraIdentity } from "../ultraIdentity";
import {
  admit, allowance, settle, type CallContext, type UltraInstall, type UltraStore, type UltraSubscriber, type UltraTransaction,
} from "../ultraMetering";
import { cost, dailyBudget, dayKey, meteringMode, monthKey, ultraPolicy } from "../ultraPolicy";
import type { UltraStage } from "../ultraRequest";

/** Firestore's transaction in memory, as in the invites' tests: reads see what was committed, writes land when the work ends. */
function memoryStore(referrals: Map<string, InstallRecord> = new Map()) {
  const installs = new Map<string, UltraInstall>();
  const subscribers = new Map<string, UltraSubscriber>();
  const store: UltraStore = {
    run: async (work) => {
      const pending: (() => void)[] = [];
      const copy = <T>(value: T | undefined) => (value === undefined ? undefined : (structuredClone(value) as T));
      const transaction: UltraTransaction = {
        install: async (id) => {
          assert.equal(pending.length, 0, "read after a write");
          return copy(installs.get(id));
        },
        subscriber: async (id) => {
          assert.equal(pending.length, 0, "read after a write");
          return copy(subscribers.get(id));
        },
        referral: async (id) => {
          assert.equal(pending.length, 0, "read after a write");
          return copy(referrals.get(id));
        },
        setInstall: (id, record) => pending.push(() => installs.set(id, structuredClone(record))),
        setSubscriber: (id, record) => pending.push(() => subscribers.set(id, structuredClone(record))),
      };
      const result = await work(transaction);
      for (const write of pending) write();
      return result;
    },
  };
  return { store, installs, subscribers };
}

const install = "11111111-1111-4111-8111-111111111111";
const script = (n: number) => `33333333-3333-4333-8333-${String(n).padStart(12, "0")}`;
const minute = 60_000;
const start = Date.UTC(2026, 10, 5, 12);

function call(stage: UltraStage, n: number, pro: string | null = null): CallContext {
  return { installId: install, scriptId: stage === "fit" ? null : script(n), stage, pro: pro ? { subscriber: pro } : null };
}

/** One whole script: draft, check and polish, each settled as it ends. Returns whether every call was admitted. */
async function write(store: UltraStore, n: number, at: number, pro: string | null = null, polishArrives = true): Promise<boolean> {
  for (const stage of ["draft", "check", "review"] as const) {
    const context = call(stage, n, pro);
    if (!(await admit(store, context, at)).ok) return false;
    await settle(store, context, stage !== "review" || polishArrives, at);
  }
  return true;
}

test("a free creator writes three scripts, each charged once its polish arrives", async () => {
  const { store } = memoryStore();
  for (let n = 1; n <= ultraPolicy.freeScripts; n++) assert.ok(await write(store, n, start + n * 4 * minute));
  assert.deepEqual(await allowance(store, install, null, start + 20 * minute), {
    membership: "free", freeLeft: 0, monthLeft: 0, left: 0, freeTotal: ultraPolicy.freeScripts, monthTotal: 0,
  });
  const refused = await admit(store, call("draft", 9), start + 30 * minute);
  assert.deepEqual(refused, { ok: false, refusal: "noCredits" });
});

test("a draft holds the credit, so two scripts at once can't spend the last one twice", async () => {
  const { store } = memoryStore();
  await write(store, 1, start);
  await write(store, 2, start + minute);
  assert.ok((await admit(store, call("draft", 3), start + 2 * minute)).ok);
  assert.deepEqual(await admit(store, call("draft", 4), start + 2 * minute), { ok: false, refusal: "noCredits" });
});

test("a polish that fails or is stopped gives the credit back; a hold left alone expires", async () => {
  const { store, installs } = memoryStore();
  assert.equal(await write(store, 1, start, null, false), true);
  assert.equal(installs.get(install)?.freeUsed, 0);
  assert.equal((await allowance(store, install, null, start + minute)).left, ultraPolicy.freeScripts);
  // A draft whose app never came back: the credit returns once the hold expires.
  assert.ok((await admit(store, call("draft", 2), start + 2 * minute)).ok);
  assert.equal((await allowance(store, install, null, start + 3 * minute)).left, ultraPolicy.freeScripts - 1);
  assert.equal((await allowance(store, install, null, start + 2 * minute + ultraPolicy.reservationMs + 1)).left, ultraPolicy.freeScripts);
});

test("a polish that arrives twice charges once, and a script's stages keep their order", async () => {
  const { store, installs } = memoryStore();
  await write(store, 1, start);
  await settle(store, call("review", 1), true, start + minute);
  assert.equal(installs.get(install)?.freeUsed, 1);
  // A charged script takes no more calls; a polish with no draft before it isn't a script.
  assert.deepEqual(await admit(store, call("review", 1), start + 2 * minute), { ok: false, refusal: "script" });
  assert.deepEqual(await admit(store, call("review", 5), start + 2 * minute), { ok: false, refusal: "script" });
  // Each stage is called at most twice (the first and one retry).
  assert.ok((await admit(store, call("draft", 6), start + 3 * minute)).ok);
  assert.ok((await admit(store, call("draft", 6), start + 3 * minute)).ok);
  assert.deepEqual(await admit(store, call("draft", 6), start + 3 * minute), { ok: false, refusal: "script" });
  // A stage without a run id is refused; a fit needs none.
  assert.deepEqual(await admit(store, { installId: install, scriptId: null, stage: "draft", pro: null }, start), { ok: false, refusal: "script" });
  assert.ok((await admit(store, call("fit", 0), start + 4 * minute)).ok);
});

test("calls past the hourly ceiling wait for the hour to pass", async () => {
  const { store } = memoryStore();
  for (let n = 0; n < ultraPolicy.callsPerHour; n++) assert.ok((await admit(store, call("fit", 0), start + n)).ok);
  assert.deepEqual(await admit(store, call("fit", 0), start + 10 * minute), { ok: false, refusal: "limited" });
  assert.ok((await admit(store, call("fit", 0), start + 61 * minute)).ok);
});

test("Cue Pro adds thirty a month per subscription, after the free ones, and a new month starts over", async () => {
  const { store, subscribers } = memoryStore();
  const subscriber = "2000000123456789";
  assert.deepEqual(await allowance(store, install, { subscriber }, start), {
    membership: "pro", freeLeft: ultraPolicy.freeScripts, monthLeft: ultraPolicy.proScriptsPerMonth,
    left: ultraPolicy.freeScripts + ultraPolicy.proScriptsPerMonth, freeTotal: ultraPolicy.freeScripts, monthTotal: ultraPolicy.proScriptsPerMonth,
  });
  for (let n = 1; n <= ultraPolicy.freeScripts + 2; n++) assert.ok(await write(store, n, start + n * minute, subscriber));
  assert.deepEqual(subscribers.get(subscriber), { month: monthKey(start), monthUsed: 2 });
  const nextMonth = Date.UTC(2026, 11, 1, 1);
  assert.equal((await allowance(store, install, { subscriber }, nextMonth)).monthLeft, ultraPolicy.proScriptsPerMonth);
  // Without a verified subscription, the month's scripts aren't there.
  assert.equal((await allowance(store, install, null, start + 30 * minute)).left, 0);
});

test("friends credited on Pro add five free scripts each", async () => {
  const referrals = new Map<string, InstallRecord>([[install, { createdAt: start, code: "K7M2QX", creditedExports: 1, creditedUltra: 2 }]]);
  const { store } = memoryStore(referrals);
  assert.equal((await allowance(store, install, null, start)).freeLeft, ultraPolicy.freeScripts + 2 * ultraPolicy.scriptsPerFriend);
});

test("a verified transaction is Pro only when it is Cue's Pro, unrevoked and unexpired", () => {
  const base = {
    bundleId: "com.cuestudioteleprompter", productId: "studio.cue.pro.monthly", originalTransactionId: "2000000123456789", expiresDate: start + 1,
  };
  assert.deepEqual(proFrom(base, start), { subscriber: "2000000123456789" });
  assert.equal(proFrom({ ...base, expiresDate: start }, start), null);
  assert.equal(proFrom({ ...base, revocationDate: start - 1 }, start), null);
  assert.equal(proFrom({ ...base, productId: "studio.cue.tips" }, start), null);
  assert.equal(proFrom({ ...base, bundleId: "com.other" }, start), null);
  assert.equal(proFrom({ ...base, expiresDate: undefined }, start), null);
});

test("a transaction Apple didn't sign reads as no Pro, with Apple's roots loaded from the function's folder", async () => {
  const roots = appleRoots(new URL("../../certs", `file://${__dirname}/`).pathname);
  assert.equal(roots.length, 2);
  const verifier = appleProVerifier(roots);
  const forged = [
    Buffer.from(JSON.stringify({ alg: "ES256", x5c: ["AAAA"] })).toString("base64url"),
    Buffer.from(JSON.stringify({ bundleId: "com.cuestudioteleprompter", productId: "studio.cue.pro.monthly" })).toString("base64url"),
    "c2ln",
  ].join(".");
  assert.equal(await verifier.verify(forged, start), null);
  assert.equal(await verifier.verify("not a transaction", start), null);
});

test("what a call cost, by model, and the policy read from .env", () => {
  const opus = cost({ model: "claude-opus-5-5", input: 4_000, cacheRead: 0, cacheWrite: 0, output: 2_000 });
  assert.ok(Math.abs(opus - (4_000 * 4 + 2_000 * 20) / 1_000_000) < 1e-12);
  assert.ok(cost({ model: "claude-haiku-5-5", input: 1_000_000, cacheRead: 0, cacheWrite: 0, output: 0 }) < 0.11);
  assert.equal(dayKey(start), "2026-11-05");
  assert.equal(monthKey(start), "2026-11");
  assert.equal(meteringMode("enforce"), "enforce");
  assert.equal(meteringMode("nonsense"), "observe");
  assert.equal(dailyBudget("20"), 20);
  assert.equal(dailyBudget("0"), 0);
  assert.equal(dailyBudget("lots"), 0);
});

test("who a call is for: ids read in any case, a proof only as text of a sane size", () => {
  const id = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
  assert.deepEqual(parseUltraIdentity({ stage: "draft" }), { ok: true, identity: { installId: null, scriptId: null, proof: null } });
  assert.deepEqual(parseUltraIdentity({ installId: id, scriptId: id, proof: "eyJ.a.b" }), {
    ok: true, identity: { installId: id.toUpperCase(), scriptId: id.toUpperCase(), proof: "eyJ.a.b" },
  });
  assert.deepEqual(parseUltraIdentity({ installId: "me" }), { ok: false, reason: "installId" });
  assert.deepEqual(parseUltraIdentity({ installId: id, scriptId: 7 }), { ok: false, reason: "scriptId" });
  assert.deepEqual(parseUltraIdentity({ installId: id, proof: "x".repeat(16_001) }), { ok: false, reason: "proof" });
});
