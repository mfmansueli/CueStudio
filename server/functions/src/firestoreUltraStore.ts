import { FieldValue, type Firestore } from "firebase-admin/firestore";
import type { InstallRecord } from "./referralRules";
import type { UltraInstall, UltraStore, UltraSubscriber } from "./ultraMetering";

/**
 * Ultra AI's counts in Firestore: `ultraInstalls/{installId}`, `ultraSubscribers/{originalTransactionId}` (read with the invites'
 * `referralInstalls/{installId}`), and Cue's spend per day in `ultraSpend/{YYYY-MM-DD}`. Only the functions touch them (the rules refuse every
 * client); each step on a creator's scripts is one transaction, so two calls at once never spend the same credit.
 */
export function firestoreUltraStore(db: Firestore): UltraStore {
  const installs = db.collection("ultraInstalls");
  const subscribers = db.collection("ultraSubscribers");
  const referrals = db.collection("referralInstalls");
  return {
    run: (work) =>
      db.runTransaction(async (transaction) =>
        work({
          install: async (id) => (await transaction.get(installs.doc(id))).data() as UltraInstall | undefined,
          subscriber: async (id) => (await transaction.get(subscribers.doc(id))).data() as UltraSubscriber | undefined,
          referral: async (id) => (await transaction.get(referrals.doc(id))).data() as InstallRecord | undefined,
          setInstall: (id, record) => {
            transaction.set(installs.doc(id), record);
          },
          setSubscriber: (id, record) => {
            transaction.set(subscribers.doc(id), record);
          },
        }),
      ),
  };
}

/** Cue's spend on Claude, by day: read before a call, added to after it. */
export interface SpendLedger {
  spent(day: string): Promise<number>;
  add(day: string, usd: number): Promise<void>;
}

export function firestoreSpendLedger(db: Firestore): SpendLedger {
  const days = db.collection("ultraSpend");
  return {
    spent: async (day) => ((await days.doc(day).get()).data()?.usd as number | undefined) ?? 0,
    add: async (day, usd) => {
      await days.doc(day).set({ usd: FieldValue.increment(usd), calls: FieldValue.increment(1) }, { merge: true });
    },
  };
}
