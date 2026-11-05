import type { Firestore } from "firebase-admin/firestore";
import type { CodeRecord, InstallRecord, ReferralStore } from "./referralRules";

/**
 * The invites in Firestore: `referralInstalls/{installId}` and `referralCodes/{code}`. Only this function writes them (the database's rules
 * refuse every client), and each step is one transaction, so two friends exporting at once both count.
 */
export function firestoreReferralStore(db: Firestore): ReferralStore {
  const installs = db.collection("referralInstalls");
  const codes = db.collection("referralCodes");
  return {
    run: (work) =>
      db.runTransaction(async (transaction) =>
        work({
          install: async (id) => (await transaction.get(installs.doc(id))).data() as InstallRecord | undefined,
          code: async (code) => (await transaction.get(codes.doc(code))).data() as CodeRecord | undefined,
          setInstall: (id, record) => {
            transaction.set(installs.doc(id), record);
          },
          setCode: (code, record) => {
            transaction.set(codes.doc(code), record);
          },
        }),
      ),
  };
}
