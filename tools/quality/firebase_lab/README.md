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

## Editorial refinement (experimental, still outside the app)

The UI now separates the official SDK in `FirebaseProbe.mjs` from pure prompt/context builders and offers:

- `recorded-control`: one call with the frozen original instructions/context.
- `editorial-v1`: a generous authoring prompt with biography/fact/narrator constraints, one call.
- `editorial-v1-reviewed`: the same draft followed by an independent editorial revision, two calls. Both draft and final are saved.
- `content-first-v2`: the writer receives identity, audience, knowledge and original request, while delivery habits are deferred.
- `content-first-v2-reviewed`: the editor receives the original voice context and applies it without throwing away reasoning/examples. In this request-local context only, the habitual twelve-word sentence cap is interpreted as a short, varied sentence preference. The exact current user request, hard constraints and stored profile remain unchanged. No duration quota or minimum word count is added.

The context projection uses known frozen prompt markers in this prototype; production should use the existing structured request/profile values instead of parsing formatted strings. Non-PT-BR refinement is explicitly rejected, not silently treated as validated. Each phase records its exact actual input, request fingerprint, requested model, tokens, finish reason and elapsed time. The source input fingerprint is distinct from hashes of adapted stage requests. Two-call results are not cost-equivalent to one-call controls.

The reviewer returns strict JSON containing a final spoken script and a short list of editorial changes. This is an editorial artifact, not chain-of-thought or a factual-verification guarantee. Invalid/incomplete reviews are failures; a captured draft remains visible as a draft and is never silently labeled final. No claims of web research, citations, or independent fact-checking are made by this ungrounded review step.

Run pure flow contracts:

```sh
node --test tools/quality/firebase_lab/*.test.mjs
```


### Agent Platform continuation and creative drafts

The isolated project was linked to billing by its owner. Current local configuration explicitly requires
`backend: agent-platform`, `location: global` and `AgentPlatformBackend` (SDK13.1.0). There is no fallback
to the Developer API. Credit eligibility does not prove actual credit application; inspect Cloud billing.
A server-side ledger in ignored `build/firebase-quality/agent-platform-budget.json` reserves at most eight
SDK invocations for this batch, including failures, surviving reloads/restarts. This is not a Cloud billing cap
and does not measure SDK transport retries. Do not delete/reset the ledger to silently expand the batch.
Only allowed Flash model names may be reserved. Draft and phase checkpoints upsert the same sample ID.

V3 is retained as an experiment in stricter autobiographical review, not the owner's desired final policy.
The owner clarified that creative first-person scenes and imagined personal expression are welcome in an
editable draft. V4 therefore permits these while preserving supplied facts, literal requests and explicit
prohibitions. Technical claims, studies, actual test results, endorsements, prices and credentials cannot
be fabricated. Review should develop the creator's ideas and voice rather than sanitize the draft.
No production app behavior or policy changed. These variants currently support PT-BR only.
