# Cue's server

Firebase project `cuestudio-app` (Cloud Functions, 2nd gen, `us-central1`). One function today:

- **`ultra`**: Ultra AI's calls to Claude. The app sends the stage's instructions, prompt and JSON shape with a Firebase App Check token
  (App Attest on a real iPhone, a registered debug token in Debug builds); the function checks the token, adds the Claude API key (Secret
  Manager, `ANTHROPIC_API_KEY`), the model and the limits, and streams Claude's events back. Its log keeps stage, model, token counts, time and
  how the call ended, never the text. DESIGN_PROJECT §57 describes it from the app's side.

## Changing the model or the effort

Edit `functions/.env` (`ULTRA_MODEL`: `claude-opus-5-5`, `claude-sonnet-5-5` or `claude-haiku-5-5`; `ULTRA_EFFORT`: `low`, `medium` or
`high`), then publish: `firebase deploy --only functions:ultra --project cuestudio-app` from this folder. No new app build.

## Setting up (or changing the key)

`server/setup.sh [key file]` stores the key (from a file, never printed), tests and publishes the function, and registers App Check
(App Attest and the lab's debug token). It needs the Firebase CLI logged in with an owner of `cuestudio-app`.

## Testing

`npm test` in `functions/` (Node's own test runner): what the function accepts, the Claude request it builds and the statuses the app reads.

## Reading what it spent

Cloud Logging, `ultra_call` entries (tokens per call and the model), or the Claude Console's usage page. Failures the owner has to fix
(no credits left, a revoked key) are logged as errors: `ultra_failed` with `kind` `credits` or `key`.
