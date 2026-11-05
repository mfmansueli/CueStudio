/**
 * What the app sends to `referral` (`CueServerReferralClient` in the app): which step, the install's random id, for "redeem" the code the
 * friend typed, and for "status" on Cue Pro the App Store's signed transaction (so friends are credited as Ultra AI scripts). Nothing else
 * about the creator: no name, no account, no contacts.
 */
export type ReferralAction = "status" | "redeem" | "activate";

export interface ReferralRequest {
  action: ReferralAction;
  installId: string;
  code: string | null;
  /** The App Store's signed Pro transaction, for "status" only. */
  proof: string | null;
}

export type ParsedReferralRequest = { ok: true; request: ReferralRequest } | { ok: false; reason: string };

const actions: readonly ReferralAction[] = ["status", "redeem", "activate"];
/** A UUID as Foundation writes it (upper case) or in lower case. */
const uuid = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
/** Longer than any code typed with spaces and dashes; the rules read the code itself. */
const typedCharacters = 32;
/** A signed transaction runs 2–4 KB. */
const proofCharacters = 16_000;

export function parseReferralRequest(body: unknown): ParsedReferralRequest {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { ok: false, reason: "body" };
  const fields = body as Record<string, unknown>;
  if (!actions.includes(fields.action as ReferralAction)) return { ok: false, reason: "action" };
  const action = fields.action as ReferralAction;
  if (typeof fields.installId !== "string" || !uuid.test(fields.installId)) return { ok: false, reason: "installId" };
  const installId = fields.installId.toUpperCase();
  if (action === "status") {
    const proof = fields.proof ?? null;
    if (proof !== null && (typeof proof !== "string" || proof.length === 0 || proof.length > proofCharacters)) return { ok: false, reason: "proof" };
    return { ok: true, request: { action, installId, code: null, proof: proof as string | null } };
  }
  if (action !== "redeem") return { ok: true, request: { action, installId, code: null, proof: null } };
  if (typeof fields.code !== "string" || fields.code.trim().length === 0 || fields.code.length > typedCharacters) {
    return { ok: false, reason: "code" };
  }
  return { ok: true, request: { action, installId, code: fields.code, proof: null } };
}
