# Cue's server

Firebase project `cuestudio-app` (Cloud Functions, 2nd gen, `us-central1`). Two functions:

- **`ultra`**: Ultra AI's calls to Claude. The app sends the stage's instructions, prompt and JSON shape with a Firebase App Check token
  (App Attest on a real iPhone, a registered debug token in Debug builds); the function checks the token, adds the Claude API key (Secret
  Manager, `ANTHROPIC_API_KEY`), the model and the limits, and streams Claude's events back. Its log keeps stage, model, token counts, time and
  how the call ended, never the text. DESIGN_PROJECT §57 describes it from the app's side. It also meters Ultra AI (below): each creator's
  scripts, Cue's daily spend, and Cue Pro checked with Apple.
- **`referral`**: the invites. With an App Check token and the install's random id, the app asks for its code and counts (`status`), joins
  a friend's code (`redeem`) and tells that the invited install exported its first video (`activate`). Each step is one Firestore transaction
  on `referralInstalls/{installId}` and `referralCodes/{code}`; `firestore.rules` refuses every client, so only the function (Admin SDK) reads
  or writes them. Its log keeps the step's outcome, never a code or an id. DESIGN_PROJECT §60.

## Publishing the invites

Once: create the Firestore database (Native mode) in `cuestudio-app` (Console › Firestore, or `firebase firestore:databases:create "(default)"
--location nam5 --project cuestudio-app`). Then from this folder: `firebase deploy --only functions:referral,firestore:rules --project
cuestudio-app`. App Check is the one `ultra` already uses.

## Metering Ultra AI

The app names the install (its random id, the invites' one), the run (one id for a script's draft, check and polish) and, on Cue Pro, the App
Store's signed transaction (`ultraIdentity.ts`). `ultraMetering.ts` holds a credit at the draft and spends it once when the polish arrives
(`ultraInstalls/{installId}`, `ultraSubscribers/{originalTransactionId}`): 3 free scripts, 5 more per friend credited on Pro, Pro's 30 a month
per subscription, 20 calls an hour. `storeProof.ts` verifies the transaction up to Apple's roots in `functions/certs/` (Apple Root CA G3 and G2,
from apple.com/certificateauthority) with Apple's `@apple/app-store-server-library`. Each call's cost goes into `ultraSpend/{YYYY-MM-DD}` (UTC).

In `functions/.env`:

- `ULTRA_METERING`: `off`, `observe` (the default: counts and logs `ultra_would_refuse`, refuses nobody) or `enforce` (402 with no scripts left,
  429 past the hourly ceiling, 409 a stage out of order, 426 a build that sends no ids; each with `X-Ultra-Refusal`).
- `ULTRA_DAILY_BUDGET_USD`: Cue's most per UTC day on Claude (default `20`; `0` is none). Past it every call gets 503 `paused` until the next day,
  in `observe` and `enforce`.

`{"action": "allowance"}` (same App Check and ids) answers `{metering, paused, membership, freeLeft, monthLeft, left, freeTotal, monthTotal}`.
Before `enforce`: let `observe` run on TestFlight with the build that sends the ids, and read `ultra_would_refuse` and `ultraSpend`.

## Changing the model or the effort

Edit `functions/.env` (`ULTRA_MODEL`: `claude-opus-5-5`, `claude-sonnet-5-5` or `claude-haiku-5-5`; `ULTRA_EFFORT`: `low`, `medium` or
`high`), then publish: `firebase deploy --only functions:ultra --project cuestudio-app` from this folder. No new app build.

## Setting up (or changing the key)

`server/setup.sh [key file]` stores the key (from a file, never printed), tests and publishes the function, and registers App Check
(App Attest and the lab's debug token). It needs the Firebase CLI logged in with an owner of `cuestudio-app`.

## Testing

`npm test` in `functions/` (Node's own test runner): what the functions accept, the Claude request `ultra` builds, the statuses the app reads,
the invites' rules on an in-memory transaction (a code made once, a friend joining once, a first export counted once, rewards stopping at 5,
each friend credited once as exports or Ultra AI scripts), and Ultra AI's metering (credits held and spent once, given back on a failure, the
hourly ceiling, Pro's month, a forged transaction read as no Pro, costs by model).

## Reading what it spent

Cloud Logging, `ultra_call` entries (tokens, the model and `usd` per call), the day's total in Firestore (`ultraSpend/{YYYY-MM-DD}`), or the
Claude Console's usage page. Failures the owner has to fix
(no credits left, a revoked key) are logged as errors: `ultra_failed` with `kind` `credits` or `key`.
