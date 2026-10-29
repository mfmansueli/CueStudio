# Firebase script-quality laboratory

Test-only web client, outside the iOS targets. Uses the official Firebase JS SDK 13.1.0 and Gemini Developer API through Firebase AI Logic. The owner authorized creating `cue-script-ai-lab`, accepted API terms at activation time and authorized the isolated local App Check debug token. The project stays Spark, no billing/hosting/analytics/AI monitoring enabled in this setup. Production Cue configuration and privacy copy are unchanged.

Run from the repository root:

```sh
python3 tools/quality/firebase_lab/server.py --config build/firebase-quality/config.json
```

Open the printed loopback URL. The local ignored JSON contains `firebase` web configuration, `model` and `debugToken`. Its debug token must be registered in this app's Firebase App Check console. Never commit the configuration, print the token or use this debug provider in production. The debug placeholder site key is only used with the official debug-token flow, not production attestation. The token can be revoked from App Check after testing.

Six frozen synthetic conditions reuse exact instructions, current prompt and response cap from recorded single-call PCC runs. References, reviewer checks and literal expectations are retained locally but are not sent to the Gemini model. One original PCC tutorial request was refused: preserve it as a refusal, never a successful control. Source inputs have SHA-256 audit fingerprints. Same token cap does not imply the same tokenizer or internal thinking budget across providers. Default sampling and reasoning remain provider-specific.

The initial model was gemini-3.8-flash; a manual selector also offers the documented stable gemini-3.5-flash. Model changes are explicit and recorded, never automatic fallback. A 60000ms SDK request timeout is now used (the first recorded request used the SDK default of 180000ms). App Check preflight time is recorded separately after the initial diagnostic update.

One generation per explicit button click; no automatic retry, repair, provider fallback or guardrail weakening. The page preflights App Check, counts attempted generation calls, and stops after 20 in a page session. Refresh resets that UI counter: it is a convenience limit, not a billing quota. Configured Firebase project/provider quotas remain authoritative. Both successes and failures are saved incrementally to ignored `build/firebase-quality/results.json` by a loopback-only server. Calls after a transport failure may still have consumed provider quota. Browser/SDK overhead means timing is end-to-end web latency, not an iPhone app performance benchmark.

Initial six conditions are PT-BR, full synthetic voice or no voice. They are an exploratory screen, not evidence for all languages or a full migration. Inspect actual prose for progression, causal explanation, useful concrete examples, faithful supplied facts, no invented biography, voice fit and requested genre. A larger word count or a successful HTTP response is not a quality win. Use independent prompts, repeated samples, partial voice, Find Inspiration and English/Spanish controls before a production decision.

Validate offline:

```sh
(cd tools/quality/firebase_lab && python3 -m unittest -v)
node --check --input-type=module < tools/quality/firebase_lab/client.js
```

Official references:
- https://firebase.google.com/docs/ai-logic/get-started
- https://firebase.google.com/docs/ai-logic/generate-text
- https://firebase.google.com/docs/ai-logic/models
- https://firebase.google.com/docs/ai-logic/pricing
- https://firebase.google.com/docs/app-check/web-debug-provider
