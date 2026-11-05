/**
 * An invite code: six characters a friend can read aloud and type without mistaking one for another (no I, O, 0 or 1). About a billion
 * codes, so a guess almost never lands on one that exists.
 */
export const codeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const codeLength = 6;

/** A new code from `random` (0 ≤ value < 1 for each character). */
export function newCode(random: () => number = Math.random): string {
  let code = "";
  for (let index = 0; index < codeLength; index++) {
    code += codeAlphabet[Math.floor(random() * codeAlphabet.length) % codeAlphabet.length];
  }
  return code;
}

/** What the friend typed, as a code: upper case, without spaces or dashes. Null when it can't be one. */
export function normalizedCode(typed: string): string | null {
  const code = typed.toUpperCase().replace(/[\s-]/g, "");
  if (code.length !== codeLength) return null;
  for (const character of code) {
    if (!codeAlphabet.includes(character)) return null;
  }
  return code;
}
