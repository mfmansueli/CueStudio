# Cue's server

Firebase project `cuestudio-app` (Cloud Functions, 2nd gen, `us-central1`). Two functions:

- **`ultra`**: Ultra AI's calls to Claude. The app sends the stage's instructions, prompt and JSON shape with a Firebase App Check token
  (App Attest on a real iPhone, a registered debug token in Debug builds); the function checks the token, adds the Claude API key (Secret
  Manager, `ANTHROPIC_API_KEY`), the model and the limits, and streams Claude's events back. Its log keeps stage, model, token counts, time and
  how the call ended, never the text. DESIGN_PROJECT §57 describes it from the app's side.
- **`referral`**: the invites. With an App Check token and the install's random id, the app asks for its code and counts (`status`), joins
  a friend's code (`redeem`) and tells that the invited install exported its first video (`activate`). Each step is one Firestore transaction
  on `referralInstalls/{installId}` and `referralCodes/{code}`; `firestore.rules` refuses every client, so only the function (Admin SDK) reads
  or writes them. Its log keeps the step's outcome, never a code or an id. DESIGN_PROJECT §60.

## Publishing the invites

Once: create the Firestore database (Native mode) in `cuestudio-app` (Console › Firestore, or `firebase firestore:databases:create "(default)"
--location nam5 --project cuestudio-app`). Then from this folder: `firebase deploy --only functions:referral,firestore:rules --project
cuestudio-app`. App Check is the one `ultra` already uses.

## Changing the model or the effort

Edit `functions/.env` (`ULTRA_MODEL`: `claude-opus-5-5`, `claude-sonnet-5-5` or `claude-haiku-5-5`; `ULTRA_EFFORT`: `low`, `medium` or
`high`), then publish: `firebase deploy --only functions:ultra --project cuestudio-app` from this folder. No new app build.

## Setting up (or changing the key)

`server/setup.sh [key file]` stores the key (from a file, never printed), tests and publishes the function, and registers App Check
(App Attest and the lab's debug token). It needs the Firebase CLI logged in with an owner of `cuestudio-app`.

## Testing

`npm test` in `functions/` (Node's own test runner): what the functions accept, the Claude request `ultra` builds, the statuses the app reads,
and the invites' rules on an in-memory transaction (a code made once, a friend joining once, a first export counted once, rewards stopping at 5).

## Reading what it spent

Cloud Logging, `ultra_call` entries (tokens per call and the model), or the Claude Console's usage page. Failures the owner has to fix
(no credits left, a revoked key) are logged as errors: `ultra_failed` with `kind` `credits` or `key`.
