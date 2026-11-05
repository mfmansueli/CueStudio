import { Environment, SignedDataVerifier } from "@apple/app-store-server-library";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { ProProof } from "./ultraMetering";

/**
 * Cue Pro, proved: the app sends the App Store's signed transaction for its current Pro subscription (StoreKit 2's `jwsRepresentation`), and
 * the server checks Apple's signature up to Apple's root certificates (`certs/`), the bundle, the product, that it wasn't refunded or
 * revoked and that it hasn't expired. The server never takes the app's word that a creator is on Pro. A transaction from Xcode's local
 * StoreKit testing isn't signed by Apple and reads as no Pro.
 */
export interface ProVerifier {
  verify(signedTransaction: string, now: number): Promise<ProProof | null>;
}

export const bundleId = "com.cuestudioteleprompter";
/** Cue's Apple ID in App Store Connect (the app's `CUE_APP_STORE_ID`). */
export const appAppleId = 6817889695;
export const proProducts: readonly string[] = ["studio.cue.pro.annual", "studio.cue.pro.monthly"];

/** The fields of a decoded transaction the server reads. */
export interface TransactionFields {
  bundleId?: string;
  productId?: string;
  originalTransactionId?: string;
  expiresDate?: number;
  revocationDate?: number;
}

/** A verified transaction is Pro when it is Cue's, one of the Pro products, not revoked, and not expired. */
export function proFrom(transaction: TransactionFields, now: number): ProProof | null {
  if (transaction.bundleId !== bundleId) return null;
  if (!transaction.productId || !proProducts.includes(transaction.productId)) return null;
  if (!transaction.originalTransactionId || transaction.revocationDate) return null;
  if (transaction.expiresDate === undefined || transaction.expiresDate <= now) return null;
  return { subscriber: transaction.originalTransactionId };
}

/** Apple's root certificates, shipped with the function. */
export function appleRoots(folder = join(__dirname, "..", "certs")): Buffer[] {
  return ["AppleRootCA-G3.cer", "AppleRootCA-G2.cer"].map((name) => readFileSync(join(folder, name)));
}

/** A verified answer is kept a few minutes, so a script's three calls check Apple's chain once. */
const remembered = 10 * 60_000;

/** The verifier for the App Store and TestFlight (sandbox) transactions. */
export function appleProVerifier(roots: Buffer[] = appleRoots()): ProVerifier {
  const verifiers = [
    new SignedDataVerifier(roots, true, Environment.PRODUCTION, bundleId, appAppleId),
    new SignedDataVerifier(roots, true, Environment.SANDBOX, bundleId),
  ];
  const cache = new Map<string, { at: number; fields: TransactionFields | null }>();
  return {
    async verify(signedTransaction, now) {
      const known = cache.get(signedTransaction);
      if (known && now - known.at < remembered) return known.fields ? proFrom(known.fields, now) : null;
      let fields: TransactionFields | null = null;
      for (const verifier of verifiers) {
        try {
          fields = await verifier.verifyAndDecodeTransaction(signedTransaction);
          break;
        } catch {
          // Not this environment's, or not Apple's at all.
        }
      }
      if (cache.size > 1_000) cache.clear();
      cache.set(signedTransaction, { at: now, fields });
      return fields ? proFrom(fields, now) : null;
    },
  };
}
