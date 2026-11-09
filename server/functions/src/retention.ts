/**
 * How long Cue's server keeps Ultra AI's counts for an install or a subscription that stopped using it: about 13 months after the last
 * script. Each write moves `expireAt` forward; Firestore's TTL policy on that field (`firestore.indexes.json`) deletes the document once the
 * date passes. The counts hold no text, name or contact, only a random install id or Apple's subscription id, and exist so the free scripts
 * and Pro's month can't be spent twice (the privacy policy says so).
 */
export const RETENTION_DAYS = 400;

const DAY_MS = 24 * 60 * 60 * 1000;

/** When a document written at `now` (milliseconds) may be deleted, in milliseconds. */
export function retentionEnd(now: number): number {
  return now + RETENTION_DAYS * DAY_MS;
}
