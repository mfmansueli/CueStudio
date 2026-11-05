import assert from "node:assert/strict";
import { test } from "node:test";
import { codeAlphabet, codeLength, newCode, normalizedCode } from "../referralCode";
import { parseReferralRequest } from "../referralRequest";
import {
  activate, redeem, rewardedFriends, status, type CodeRecord, type InstallRecord, type ReferralStore, type ReferralTransaction,
} from "../referralRules";

/** Firestore's transaction in memory: reads see what was committed, writes land when the work ends, and a read after a write is a mistake. */
function memoryStore() {
  const installs = new Map<string, InstallRecord>();
  const codes = new Map<string, CodeRecord>();
  const store: ReferralStore = {
    run: async (work) => {
      const pending: (() => void)[] = [];
      const transaction: ReferralTransaction = {
        install: async (id) => {
          assert.equal(pending.length, 0, "read after a write");
          const record = installs.get(id);
          return record && { ...record };
        },
        code: async (code) => {
          assert.equal(pending.length, 0, "read after a write");
          const record = codes.get(code);
          return record && { ...record };
        },
        setInstall: (id, record) => pending.push(() => installs.set(id, { ...record })),
        setCode: (code, record) => pending.push(() => codes.set(code, { ...record })),
      };
      const result = await work(transaction);
      for (const write of pending) write();
      return result;
    },
  };
  return { store, installs, codes };
}

const creator = "11111111-1111-4111-8111-111111111111";
const friend = (n: number) => `22222222-2222-4222-8222-${String(n).padStart(12, "0")}`;

test("a code is six characters a friend can't misread, and what they type is read without spaces, dashes or case", () => {
  const code = newCode();
  assert.equal(code.length, codeLength);
  for (const character of code) assert.ok(codeAlphabet.includes(character));
  for (const confusable of ["I", "O", "0", "1"]) assert.ok(!codeAlphabet.includes(confusable));
  assert.equal(normalizedCode(" k7m-2qx "), "K7M2QX");
  assert.equal(normalizedCode("k7m 2qx"), "K7M2QX");
  assert.equal(normalizedCode("K7M2Q0"), null);
  assert.equal(normalizedCode("K7M2Q"), null);
});

test("the creator's code is made once and kept", async () => {
  const { store } = memoryStore();
  const first = await status(store, creator, 1, () => "K7M2QX");
  const again = await status(store, creator, 2, () => "ZZZZZZ");
  assert.deepEqual(first, {
    code: "K7M2QX", joined: 0, activated: 0, rewarded: 0, limit: rewardedFriends, friendsAsExports: 0, friendsAsUltraScripts: 0,
  });
  assert.equal(again.code, "K7M2QX");
});

test("a code someone already has is never handed out twice", async () => {
  const { store } = memoryStore();
  await status(store, creator, 1, () => "K7M2QX");
  const made = ["K7M2QX", "K7M2QX", "P4WHNB"];
  const other = await status(store, friend(1), 1, () => made.shift()!);
  assert.equal(other.code, "P4WHNB");
});

test("a friend who types the code joins once; their first export counts once for the creator", async () => {
  const { store, installs } = memoryStore();
  const { code } = await status(store, creator, 1);
  assert.equal(await redeem(store, friend(1), code.toLowerCase(), 2), "joined");
  assert.equal(await redeem(store, friend(1), code, 3), "already");
  assert.deepEqual(await status(store, creator, 4), {
    code, joined: 1, activated: 0, rewarded: 0, limit: rewardedFriends, friendsAsExports: 0, friendsAsUltraScripts: 0,
  });
  assert.equal(await activate(store, friend(1), 5), "counted");
  assert.equal(await activate(store, friend(1), 6), "already");
  assert.deepEqual(await status(store, creator, 7), {
    code, joined: 1, activated: 1, rewarded: 1, limit: rewardedFriends, friendsAsExports: 1, friendsAsUltraScripts: 0,
  });
  assert.equal(installs.get(friend(1))?.invitedBy, code);
});

test("the creator's own code and an unknown one join nobody, and an export with no invite counts for no one", async () => {
  const { store } = memoryStore();
  const { code } = await status(store, creator, 1);
  assert.equal(await redeem(store, creator, code, 2), "own");
  assert.equal(await redeem(store, friend(1), "ABCDEF", 2), "unknown");
  assert.equal(await redeem(store, friend(1), "not a code", 2), "unknown");
  assert.equal(await activate(store, friend(2), 3), "notInvited");
  assert.equal((await status(store, creator, 4)).joined, 0);
});

test("an install nobody invited never leaves a trace when it exports", async () => {
  const { store, installs } = memoryStore();
  assert.equal(await activate(store, friend(3), 1), "notInvited");
  assert.equal(installs.size, 0);
});

test("rewards stop at the limit; friends keep counting", async () => {
  const { store } = memoryStore();
  const { code } = await status(store, creator, 1);
  for (let n = 1; n <= rewardedFriends + 2; n++) {
    assert.equal(await redeem(store, friend(n), code, n), "joined");
    assert.equal(await activate(store, friend(n), n), "counted");
  }
  const summary = await status(store, creator, 100);
  assert.equal(summary.activated, rewardedFriends + 2);
  assert.equal(summary.rewarded, rewardedFriends);
});

test("each rewarded friend is credited once, in the kind the creator's verified plan called for then", async () => {
  const { store } = memoryStore();
  const { code } = await status(store, creator, 1);
  for (let n = 1; n <= 2; n++) {
    await redeem(store, friend(n), code, n);
    await activate(store, friend(n), n);
  }
  // Two friends while on the free plan: exports.
  let summary = await status(store, creator, 10);
  assert.equal(summary.friendsAsExports, 2);
  assert.equal(summary.friendsAsUltraScripts, 0);
  // The creator moves to Pro: those two stay exports, the next friends are Ultra AI scripts, up to the limit.
  for (let n = 3; n <= rewardedFriends + 1; n++) {
    await redeem(store, friend(n), code, n);
    await activate(store, friend(n), n);
  }
  summary = await status(store, creator, 20, undefined, true);
  assert.equal(summary.friendsAsExports, 2);
  assert.equal(summary.friendsAsUltraScripts, rewardedFriends - 2);
  // Asked again, nothing is credited twice.
  summary = await status(store, creator, 30, undefined, false);
  assert.equal(summary.friendsAsExports + summary.friendsAsUltraScripts, rewardedFriends);
});

test("a friend can't switch to another creator's code", async () => {
  const { store } = memoryStore();
  const first = await status(store, creator, 1);
  const second = await status(store, friend(9), 1);
  assert.equal(await redeem(store, friend(1), first.code, 2), "joined");
  assert.equal(await redeem(store, friend(1), second.code, 3), "already");
  assert.equal((await status(store, friend(9), 4)).joined, 0);
});

test("only what the app sends is accepted, by kind", () => {
  const id = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
  assert.deepEqual(parseReferralRequest({ action: "status", installId: id }), {
    ok: true, request: { action: "status", installId: id.toUpperCase(), code: null, proof: null },
  });
  assert.deepEqual(parseReferralRequest({ action: "status", installId: id, proof: "eyJ.a.b" }), {
    ok: true, request: { action: "status", installId: id.toUpperCase(), code: null, proof: "eyJ.a.b" },
  });
  assert.deepEqual(parseReferralRequest({ action: "redeem", installId: id, code: "k7m-2qx" }), {
    ok: true, request: { action: "redeem", installId: id.toUpperCase(), code: "k7m-2qx", proof: null },
  });
  const cases: [unknown, string][] = [
    [null, "body"],
    [[], "body"],
    [{ action: "grant", installId: id }, "action"],
    [{ action: "status", installId: "me" }, "installId"],
    [{ action: "redeem", installId: id }, "code"],
    [{ action: "redeem", installId: id, code: "  " }, "code"],
    [{ action: "redeem", installId: id, code: "x".repeat(33) }, "code"],
    [{ action: "status", installId: id, proof: 42 }, "proof"],
    [{ action: "status", installId: id, proof: "x".repeat(16_001) }, "proof"],
  ];
  for (const [body, reason] of cases) assert.deepEqual(parseReferralRequest(body), { ok: false, reason });
});
