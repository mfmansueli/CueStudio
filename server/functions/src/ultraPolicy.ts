/**
 * Ultra AI's allowance and guards on Cue's server (DESIGN_PROJECT §57): how many scripts each creator may write, how fast, and how much Cue
 * may spend on Claude in a day. The numbers match the app's (`UsagePolicy`, `ReferralRewards`).
 */

/**
 * How the server meters Ultra AI (`ULTRA_METERING` in `.env`):
 * - "off": as before metering existed; nothing is counted or refused.
 * - "observe": counts every creator's scripts and Cue's daily spend, refuses only past the daily budget, and logs what "enforce" would have
 *   refused. Builds that send no install id (TestFlight before this server) keep working.
 * - "enforce": also refuses a script past the creator's allowance, calls past the hourly ceiling, and builds that don't say who they are.
 */
export type MeteringMode = "off" | "observe" | "enforce";

export const meteringModes: readonly MeteringMode[] = ["off", "observe", "enforce"];

export const ultraPolicy = {
  /** Free scripts per install, for life (`UsagePolicy.freeUltraScripts`). */
  freeScripts: 3,
  /** Cue Pro's scripts each calendar month, UTC (`UsagePolicy.proUltraScriptsPerMonth`). */
  proScriptsPerMonth: 30,
  /** Scripts each friend earns a Pro creator who invited them (`ReferralRewards.ultraScriptsPerFriend`). */
  scriptsPerFriend: 5,
  /** Calls one install may make in an hour: a script is two or three, a fit one; a creator writing fast stays well under it. */
  callsPerHour: 20,
  /** How long a script's credit is held between its draft and its polish before it is given back. */
  reservationMs: 15 * 60_000,
  /** Times each stage of one script may be called (the first and one retry). */
  callsPerStage: 2,
  /** Charged scripts remembered per install, so a retried polish never charges twice. */
  chargedKept: 50,
};

/** USD per million tokens (Anthropic's pricing page, read 02/11/2026, as the app's `UltraPrice`). Cache writes are 1.25 times the input. */
export interface Price {
  input: number;
  cacheRead: number;
  cacheWrite: number;
  output: number;
}

export function price(model: string): Price {
  if (model.startsWith("claude-opus")) return { input: 4, cacheRead: 0.2, cacheWrite: 5, output: 20 };
  if (model.startsWith("claude-haiku")) return { input: 0.1, cacheRead: 0.01, cacheWrite: 0.125, output: 0.5 };
  return { input: 2, cacheRead: 0.2, cacheWrite: 2.5, output: 10 };
}

/** One call's tokens, as Claude's stream reports them. */
export interface Usage {
  model: string;
  input: number;
  cacheRead: number;
  cacheWrite: number;
  output: number;
}

/** What one call cost, in USD. */
export function cost(usage: Usage): number {
  const rates = price(usage.model);
  return (
    (usage.input * rates.input + usage.cacheRead * rates.cacheRead + usage.cacheWrite * rates.cacheWrite + usage.output * rates.output) /
    1_000_000
  );
}

/** The day Cue's spend is counted in, UTC ("2026-11-05"). */
export function dayKey(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}

/** The month Pro's scripts are counted in, UTC ("2026-11"). */
export function monthKey(now: number): string {
  return new Date(now).toISOString().slice(0, 7);
}

/** The metering mode from `.env`, "observe" for anything it doesn't know. */
export function meteringMode(value: string): MeteringMode {
  return meteringModes.includes(value as MeteringMode) ? (value as MeteringMode) : "observe";
}

/** The daily budget from `.env`, in USD; 0 or anything unreadable is no budget. */
export function dailyBudget(value: string): number {
  const amount = Number(value);
  return Number.isFinite(amount) && amount > 0 ? amount : 0;
}
