import type { InstallRecord } from "./referralRules";
import { monthKey, ultraPolicy } from "./ultraPolicy";
import type { UltraStage } from "./ultraRequest";

/**
 * Each creator's Ultra AI scripts, kept on Cue's server (the app's count is only what it shows). An install (the random id the app keeps in
 * the Keychain, the one the invites use) has its free scripts, plus five for each friend credited while it was on Pro; Cue Pro adds 30 a
 * month, counted per subscription (Apple's original transaction id), so a second iPhone shares them. A script is charged once, when its
 * polish arrives: the draft holds a credit, the polish spends it, and a failure or a stop gives it back. Times are milliseconds since 1970.
 */

/** One install's Ultra AI, as the server knows it. */
export interface UltraInstall {
  createdAt: number;
  /** Scripts written out of the free ones and those invites earned. */
  freeUsed: number;
  /** Scripts charged, by the id the app gave the run, and when: a polish that comes twice charges once. */
  charged: Record<string, number>;
  /** Scripts under way, by their id: a credit held from the draft until the polish ends or the hold expires. */
  reservations: Record<string, Reservation>;
  /** When the install's calls of the last hour went out. */
  recentCalls: number[];
}

export interface Reservation {
  until: number;
  /** Calls made for each stage of this script. */
  stages: Partial<Record<UltraStage, number>>;
}

/** One Cue Pro subscription's scripts this month. */
export interface UltraSubscriber {
  month: string;
  monthUsed: number;
}

/** A verified Cue Pro subscription (`storeProof`): Apple's original transaction id. */
export interface ProProof {
  subscriber: string;
}

export interface UltraTransaction {
  install(id: string): Promise<UltraInstall | undefined>;
  subscriber(id: string): Promise<UltraSubscriber | undefined>;
  /** The install's invites (`referralInstalls`), for the scripts friends earned it. */
  referral(id: string): Promise<InstallRecord | undefined>;
  setInstall(id: string, record: UltraInstall): void;
  setSubscriber(id: string, record: UltraSubscriber): void;
}

export interface UltraStore {
  run<T>(work: (transaction: UltraTransaction) => Promise<T>): Promise<T>;
}

/** What the creator has left, as the app shows it. */
export interface UltraAllowance {
  membership: "free" | "pro";
  /** Free scripts and those invites earned. */
  freeLeft: number;
  /** Cue Pro's scripts left this month. */
  monthLeft: number;
  /** Everything the creator may still write, less the scripts under way. */
  left: number;
  /** The free scripts with those invites earned, and Pro's monthly ones (0 off Pro): what the app counts out of. */
  freeTotal: number;
  monthTotal: number;
}

/** Why a call was refused: no scripts left, too many calls this hour, a stage out of a script's order, or a build that didn't say who it is. */
export type Refusal = "noCredits" | "limited" | "script" | "identity";

export interface CallContext {
  installId: string;
  /** The run's id, the same for every stage of one script; null for a fit. */
  scriptId: string | null;
  stage: UltraStage;
  pro: ProProof | null;
}

export type Admission = { ok: true; allowance: UltraAllowance } | { ok: false; refusal: Refusal };

function emptyInstall(now: number): UltraInstall {
  return { createdAt: now, freeUsed: 0, charged: {}, reservations: {}, recentCalls: [] };
}

/** Free scripts with those friends earned on Pro. */
function freeTotal(referral: InstallRecord | undefined): number {
  return ultraPolicy.freeScripts + ultraPolicy.scriptsPerFriend * (referral?.creditedUltra ?? 0);
}

function monthUsed(subscriber: UltraSubscriber | undefined, now: number): number {
  return subscriber && subscriber.month === monthKey(now) ? subscriber.monthUsed : 0;
}

/** Scripts under way, besides `except`. */
function held(install: UltraInstall, now: number, except: string | null): number {
  return Object.entries(install.reservations).filter(([id, hold]) => id !== except && hold.until > now).length;
}

export function allowanceFrom(
  install: UltraInstall, subscriber: UltraSubscriber | undefined, referral: InstallRecord | undefined, pro: ProProof | null, now: number,
  except: string | null = null,
): UltraAllowance {
  const total = freeTotal(referral);
  const freeLeft = Math.max(0, total - install.freeUsed);
  const monthLeft = pro ? Math.max(0, ultraPolicy.proScriptsPerMonth - monthUsed(subscriber, now)) : 0;
  return {
    membership: pro ? "pro" : "free", freeLeft, monthLeft, left: Math.max(0, freeLeft + monthLeft - held(install, now, except)),
    freeTotal: total, monthTotal: pro ? ultraPolicy.proScriptsPerMonth : 0,
  };
}

/** Holds that expired and calls older than an hour leave the record. */
function pruned(install: UltraInstall, now: number): UltraInstall {
  const reservations = Object.fromEntries(Object.entries(install.reservations).filter(([, hold]) => hold.until > now));
  return { ...install, reservations, recentCalls: install.recentCalls.filter((at) => at > now - 3_600_000) };
}

/**
 * May this call go out? A draft opens a script (holding a credit if the creator has one left); the claim check and the polish belong to a
 * script whose draft went out; a fit needs no script. Every admitted call counts toward the hourly ceiling.
 */
export async function admit(store: UltraStore, context: CallContext, now: number): Promise<Admission> {
  return store.run(async (transaction) => {
    const install = pruned((await transaction.install(context.installId)) ?? emptyInstall(now), now);
    const subscriber = context.pro ? await transaction.subscriber(context.pro.subscriber) : undefined;
    const referral = await transaction.referral(context.installId);
    if (install.recentCalls.length >= ultraPolicy.callsPerHour) return { ok: false, refusal: "limited" };

    const reservations = { ...install.reservations };
    if (context.stage !== "fit") {
      const scriptId = context.scriptId;
      if (!scriptId || install.charged[scriptId]) return { ok: false, refusal: "script" };
      const hold = reservations[scriptId];
      if (hold) {
        const calls = hold.stages[context.stage] ?? 0;
        if (calls >= ultraPolicy.callsPerStage) return { ok: false, refusal: "script" };
        reservations[scriptId] = {
          until: now + ultraPolicy.reservationMs, stages: { ...hold.stages, [context.stage]: calls + 1 },
        };
      } else {
        if (context.stage !== "draft") return { ok: false, refusal: "script" };
        if (allowanceFrom(install, subscriber, referral, context.pro, now).left <= 0) return { ok: false, refusal: "noCredits" };
        reservations[scriptId] = { until: now + ultraPolicy.reservationMs, stages: { draft: 1 } };
      }
    }
    const next: UltraInstall = { ...install, reservations, recentCalls: [...install.recentCalls, now] };
    transaction.setInstall(context.installId, next);
    return { ok: true, allowance: allowanceFrom(next, subscriber, referral, context.pro, now) };
  });
}

/**
 * After the call: a polish that arrived charges its script once (the free scripts first, then Pro's month, as the app's `UltraAllowance`); any
 * stage that failed or was stopped gives the held credit back. A draft or check that finished keeps the hold for the polish.
 */
export async function settle(store: UltraStore, context: CallContext, finished: boolean, now: number): Promise<void> {
  const scriptId = context.scriptId;
  if (!scriptId || context.stage === "fit") return;
  if (finished && context.stage !== "review") return;
  await store.run(async (transaction) => {
    const install = await transaction.install(context.installId);
    if (!install?.reservations[scriptId]) return;
    const subscriber = context.pro ? await transaction.subscriber(context.pro.subscriber) : undefined;
    const referral = await transaction.referral(context.installId);
    const reservations = { ...install.reservations };
    delete reservations[scriptId];
    if (!finished) {
      transaction.setInstall(context.installId, { ...install, reservations });
      return;
    }
    let freeUsed = install.freeUsed;
    if (freeUsed < freeTotal(referral)) {
      freeUsed += 1;
    } else if (context.pro) {
      transaction.setSubscriber(context.pro.subscriber, { month: monthKey(now), monthUsed: monthUsed(subscriber, now) + 1 });
    }
    const charged = Object.fromEntries(
      [...Object.entries(install.charged), [scriptId, now] as const].sort((a, b) => a[1] - b[1]).slice(-ultraPolicy.chargedKept),
    );
    transaction.setInstall(context.installId, { ...install, freeUsed, reservations, charged });
  });
}

/** What the creator has left, for the app to show (nothing is written). */
export async function allowance(store: UltraStore, installId: string, pro: ProProof | null, now: number): Promise<UltraAllowance> {
  return store.run(async (transaction) => {
    const install = pruned((await transaction.install(installId)) ?? emptyInstall(now), now);
    const subscriber = pro ? await transaction.subscriber(pro.subscriber) : undefined;
    const referral = await transaction.referral(installId);
    return allowanceFrom(install, subscriber, referral, pro, now);
  });
}
