import { newCode, normalizedCode } from "./referralCode";

/**
 * Cue's invites (owner, 05/11/2026): a creator shares a code; a friend types it in Cue before their first export; when that friend exports
 * their first video, the creator earns a reward (three exports on the free plan). Only the creator who invites is rewarded: App Review has
 * refused apps that reward the one who downloads (DESIGN_PROJECT §60). The server alone decides who joined and who exported, so a creator
 * can't grant themselves rewards; the app turns the count into exports.
 *
 * Every install is a random id the app keeps in the Keychain (it survives a reinstall); App Check proves each request comes from Cue.
 */

/** Friends whose first export earns a reward; more can join, the reward stops here. */
export const rewardedFriends = 5;

/** One install of Cue, as the server knows it. Times are milliseconds since 1970. */
export interface InstallRecord {
  createdAt: number;
  /** The install's own code, once it asked for one. */
  code?: string;
  /** The code of the creator who invited this install. */
  invitedBy?: string;
  joinedAt?: number;
  /** When this install, invited, exported its first video. */
  activatedAt?: number;
}

/** A code and how far its creator's invites went. */
export interface CodeRecord {
  installId: string;
  createdAt: number;
  /** Friends who typed it. */
  joined: number;
  /** Friends who then exported their first video. */
  activated: number;
}

/**
 * The reads and writes of one transaction. Firestore wants every read before the first write, so the rules read first and write last.
 */
export interface ReferralTransaction {
  install(id: string): Promise<InstallRecord | undefined>;
  code(code: string): Promise<CodeRecord | undefined>;
  setInstall(id: string, record: InstallRecord): void;
  setCode(code: string, record: CodeRecord): void;
}

export interface ReferralStore {
  run<T>(work: (transaction: ReferralTransaction) => Promise<T>): Promise<T>;
}

/** What the inviting creator sees: their code and how many friends joined and exported. */
export interface ReferralStatus {
  code: string;
  joined: number;
  activated: number;
  /** Friends whose first export earned a reward (at most `rewardedFriends`). */
  rewarded: number;
  limit: number;
}

export type RedeemOutcome = "joined" | "unknown" | "own" | "already";

export type ActivateOutcome = "counted" | "notInvited" | "already";

/** Tries for a code nobody has before giving up (a collision is one in a billion). */
const codeAttempts = 5;

/** The creator's code (made the first time) and their invites so far. */
export async function status(
  store: ReferralStore, installId: string, now: number, makeCode: () => string = newCode,
): Promise<ReferralStatus> {
  return store.run(async (transaction) => {
    const install = (await transaction.install(installId)) ?? { createdAt: now };
    if (install.code) {
      const record = await transaction.code(install.code);
      if (record) return summary(install.code, record);
    }
    for (let attempt = 0; attempt < codeAttempts; attempt++) {
      const code = makeCode();
      if (await transaction.code(code)) continue;
      const record: CodeRecord = { installId, createdAt: now, joined: 0, activated: 0 };
      transaction.setCode(code, record);
      transaction.setInstall(installId, { ...install, code });
      return summary(code, record);
    }
    throw new Error("no free code");
  });
}

/**
 * A friend typed a code. It counts once per install, never for the creator's own code; the app offers it only before the install's first
 * export, so an install that exported already never joins.
 */
export async function redeem(store: ReferralStore, installId: string, typed: string, now: number): Promise<RedeemOutcome> {
  const code = normalizedCode(typed);
  if (!code) return "unknown";
  return store.run(async (transaction) => {
    const install = (await transaction.install(installId)) ?? { createdAt: now };
    const record = await transaction.code(code);
    if (!record) return "unknown";
    if (record.installId === installId || install.code === code) return "own";
    if (install.invitedBy || install.activatedAt) return "already";
    transaction.setInstall(installId, { ...install, invitedBy: code, joinedAt: now });
    transaction.setCode(code, { ...record, joined: record.joined + 1 });
    return "joined";
  });
}

/** The install exported its first video: if a creator invited it, their count goes up, once. */
export async function activate(store: ReferralStore, installId: string, now: number): Promise<ActivateOutcome> {
  return store.run(async (transaction) => {
    // The app asks only once it joined: an install nobody invited never tells the server it exported.
    const install = await transaction.install(installId);
    if (!install?.invitedBy) return "notInvited";
    if (install.activatedAt) return "already";
    const record = await transaction.code(install.invitedBy);
    transaction.setInstall(installId, { ...install, activatedAt: now });
    if (record) transaction.setCode(install.invitedBy, { ...record, activated: record.activated + 1 });
    return "counted";
  });
}

function summary(code: string, record: CodeRecord): ReferralStatus {
  return {
    code,
    joined: record.joined,
    activated: record.activated,
    rewarded: Math.min(record.activated, rewardedFriends),
    limit: rewardedFriends,
  };
}
