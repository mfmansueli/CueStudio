/**
 * Who an Ultra AI call is for, beside the call itself (`ultraRequest`): the install's random id (the one the invites use), the run's id
 * (the same for every stage of one script) and, on Cue Pro, the App Store's signed transaction. Builds before metering send none of them.
 */
export interface UltraIdentity {
  installId: string | null;
  scriptId: string | null;
  proof: string | null;
}

export type ParsedUltraIdentity = { ok: true; identity: UltraIdentity } | { ok: false; reason: string };

const uuid = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
/** A signed transaction runs 2–4 KB; anything far longer isn't one. */
const proofCharacters = 16_000;

export function parseUltraIdentity(body: unknown): ParsedUltraIdentity {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { ok: false, reason: "body" };
  const fields = body as Record<string, unknown>;
  const read = (name: string): string | null | undefined => {
    const value = fields[name];
    if (value === undefined || value === null) return null;
    if (typeof value !== "string" || !uuid.test(value)) return undefined;
    return value.toUpperCase();
  };
  const installId = read("installId");
  if (installId === undefined) return { ok: false, reason: "installId" };
  const scriptId = read("scriptId");
  if (scriptId === undefined) return { ok: false, reason: "scriptId" };
  const proof = fields.proof ?? null;
  if (proof !== null && (typeof proof !== "string" || proof.length === 0 || proof.length > proofCharacters)) {
    return { ok: false, reason: "proof" };
  }
  return { ok: true, identity: { installId, scriptId, proof: proof as string | null } };
}
