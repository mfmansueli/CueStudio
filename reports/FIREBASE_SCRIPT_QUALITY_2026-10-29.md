# Firebase script-quality experiment — 2026-10-29

## Authorization and environment

The owner requested a preliminary Firebase AI comparison before any production migration/privacy changes, authorized creating a separate project in eusouoiago@gmail.com, accepted the specific Gemini API terms at activation time, and authorized registering the isolated local App Check debug token. New branch: `codex/firebase-script-quality`, based on the existing editorial experiment branch. Reused isolated worktree; main checkout and production provider/configuration untouched.

Created Firebase project **Cue Script AI Lab** (`cue-script-ai-lab`) and web app **Cue Script Quality Benchmark**, using Gemini Developer API through official Firebase AI Logic JS SDK13.1.0. Project is Spark, with no billing account linked by this work. Analytics, hosting, AI monitoring and Agent Platform provider were not enabled. Local credential/config file is ignored under `build/firebase-quality/config.json`, permissions0600; never commit it or the debug token. The token remains registered and revocable in this isolated project's App Check console. Console displayed all nine initial requests as verified. Basic App Check enforcement remains the console's original monitoring mode, scheduled automatic enforcement November2; an attempted configuration review was canceled before saving because the UI warned about the app lacking production attestation registration. No protection was disabled. Do not describe this debug laboratory as a production security setup. Production registration/enforcement must be completed separately before release.

A loopback-only web laboratory at tools/quality/firebase_lab sends one explicit request per click, with no automatic fallback/retry/repair. Requests, failures, response text, timing and token usage are captured locally. Current page limit20 is a convenience bound, not a billing quota; refresh resets it. Models/caps are explicitly recorded. The first request used SDK180s timeout; subsequent ones use60s. All inputs are frozen synthetic data, including the voice profile. No private creator samples, real user scripts or assistant reference answers were transmitted.

## Initial comparison

Raw evidence: research_notes/Firebase script quality/initial-2026-10-29.json. Six frozen conditions span **three PT-BR topics**, not six independent topics: natural script reading, camera upgrades and window-lighting tutorial. Three conditions use full synthetic voice; two bare conditions have no application instructions/profile/platform; one editorial condition uses application instructions without voice. The editorial condition was repeated unchanged. Same actual instructions/current prompt/response cap as earlier single-call raw PCC controls. Provider sampling/thinking/tokenizers differ; this is an exploratory, unblinded comparison, not a proof of maximum model capability or a finished product benchmark.

- Gemini3.8Flash: two requests yielded no text: a503 deadline at179.52s and a60s timeout. These are availability failures, not quality judgments about unseen output.
- Gemini3.5Flash: seven texts from seven requests, across six conditions, all finishReasonSTOP. Initial latency10.30–19.31s; this is end-to-end web SDK latency, not native iPhone performance.
- The PCC tutorial raw control was a framework refusal; preserve it as a refusal, not a generated baseline or proof of a Gemini quality win.

## Observations from actual prose

**Natural reading, bare:** Gemini developed the musician/partitura example and a line of reasoning much more than the short PCC control. It also prefaced the answer with assistant commentary, used Markdown, invented a past personal learning experience and described an ungrounded submillisecond thinking process. More material is useful, but not an unconditional quality pass.

**Natural reading, full voice:** clearer karaoke analogy with a concrete mechanism, casual delivery fitting the synthetic profile. However, it opened with “Eu já tentei gravar no improviso” and “passava vergonha,” despite explicit instructions not to invent the creator's past. The profile still pulled the result toward a short mistake-opening/comment-ending pattern. This is a request-fidelity/biography failure, not just a tone preference.

**Equipment, full voice:** more actionable contrast and practical framing than PCC's vague “if rhythm does not change nothing improves.” But assertions that an upgrade makes sense in only one case, when production is completely blocked, are overly absolute. Low-light capture “without losing quality” overpromises.

**Tutorial, full voice:** three distinct actions and no request to follow. The instruction to move two steps away from a window to make light softer is not a generally valid rule; apparent source size, direct/indirect sunlight, diffusion and exposure matter. General claim that front lighting is wrong is also too categorical. Do not approve this as technically correct just because it is clear and confident.

**Equipment, bare:** substantially richer output and more upgrade criteria, but essay/Markdown packaging and serious technical errors. Greater dynamic range does not inherently make highlight clipping/shadows worse, and shallow depth of field does not make background clutter sharper. The detailed hypothetical example is unreliable.

**Natural reading, editorial, two repetitions:** both developed a useful contrast between formal written phrases and spoken phrasing, with concrete before/after examples. This is a more substantive advance than simply extending word count. Both still overgeneralized that rewriting makes reading naturally effortless/invisible, used generic second-person exposition after a brief first-person opening, and added unsupported personal-observation openings. No numerical quality score or blanket approval is claimed.

The owner explicitly values the richer, generous draft material and authorized refining the experimental tool to make better use of Gemini. Preserve that breadth and authorial freedom; focus refinement on unsupported real-world claims, invented biography, perspective fidelity and coherent development rather than shrinking everything to a short safe summary. No automatic duration quota is introduced.

## Primary references

- Firebase AI Logic setup: https://firebase.google.com/docs/ai-logic/get-started
- Model availability: https://firebase.google.com/docs/ai-logic/models
- Pricing: https://firebase.google.com/docs/ai-logic/pricing
- SDK request timeout: https://firebase.google.com/docs/reference/js/ai.requestoptions
- App Check debug provider: https://firebase.google.com/docs/app-check/web-debug-provider
- Technical cross-check, source size/distance and soft light: https://lightroom.adobe.com/academy/genres/food/love-the-light

No production provider switch, privacy-policy replacement, full-language claim, native app integration, PR or merge has been made. All new executable files are outside Xcode targets; no Xcode build is required for the standalone lab. Three offline input-contract tests and JS syntax checks pass. Further controlled refinement is now authorized and in progress.

## Refinement authorized while testing

The owner values the richer arguments/material and explicitly requested making better use of Firebase AI, including an in-app polishing phase during generation. They accept20–30seconds and more margin if helpful. This authorizes experimental workflow refinement; it does not erase the original condition that a production provider migration/privacy change follow actual evaluation.

New SDK boundary `FirebaseProbe.mjs`, pure `writerFlow.mjs` and `voiceContext.mjs`; no Swift files or iOS dependencies changed. Revision output is strict JSON (`changes`, `script`), with every actual stage request/output/token usage/timing retained. A malformed/failed review is not silently replaced with a supposedly finished script. Current request and literals remain exact in the context transformation; no stored profile is edited and no duration/word-count quota is introduced.

V1 opinion with full voice:27.35s for two calls (draft18.59s, edit8.76s). Invented past experience removed, but both draft/final remained too thin. Reviewer explicitly prioritized the old twelve-word sentence preference. This is not the desired richness, despite successful technical completion. V1 tutorial: draft generated, review failed with provider500/high-demand error. The draft still contained the questionable two-steps-away/light-spreading rule. No final text or correction approval is claimed.

V2 now separates content development from delivery habits. The first stage retains identity/audience/context/current request and defers style/opening/CTA habits. The second stage receives full voice context with the numeric habitual sentence cap interpreted as a short, varied sentence preference, not a limit on substance. The user’s exact prompt is never normalized or shortened. All adapted input is recorded. This is a deliberate workflow change, not a pure same-input model comparison. Seven pure JS contracts and three Python input contracts pass; live V2 results are being assessed in the local web lab (not the iPhone).

V2 opinion result:23.71s across two calls, 332-word draft and247-word final (counts are descriptive, not a duration quota or quality score). Substantially more developed than V1's thin full-voice result; casual tone and analogy retained, invented past avoided, habitual CTA omitted. Still overstates that text style is the sole reason reading sounds robotic and that reading becomes invisible; first-person stance also drifts into general second-person exposition. Useful progress, not universal approval.

V2 equipment request failed with provider500/high demand before any draft. V2 tutorial then failed with429 daily free-tier quota20. All generation requests were stopped at that point. The local record has14 experiment runs and17 top-level generation attempts, yielding9 final texts plus preserved drafts. The provider's quota accounting reached20; internal SDK/server retries or pooling were not measured, so do not invent an exact explanation for the discrepancy. The quota response labels its dimension gemini-3.6-flash even though the requested model name was gemini-3.5-flash. Record requested names faithfully and do not claim exact resolved model version from this metadata.

## Credits-backed continuation

The owner subsequently explicitly requested linking the isolated lab to their existing billing account and personally completed the financial confirmation. Firebase verified Blaze and Agent Platform Gemini API enabled. The lab now requires AgentPlatformBackend with global location; no automatic Gemini Developer API fallback. No upgrade of the underlying Cloud trial billing account was performed by the agent. Welcome credits apply only to eligible Cloud services, not Gemini Developer API usage; actual credit consumption must be checked in Cloud billing, not inferred from successful inference.

This named continuation batch reserves at most eight top-level SDK calls on the loopback server, including failures, persisted across page reload/server restart. This is an application guard, not a Google billing hard cap or measured count of transport retries. Only the two Flash models are allowed. Draft/stage checkpoints are saved before editing and upserted by sample ID; failed reviews remain drafts. Production and native iPhone are unchanged.


### Owner clarification: imagination is part of the draft

After seeing the conservative review direction, the owner explicitly clarified that My Cue Voice should
imagine for the creator and embody their voice: invented everyday scenes/personal expression can be useful
editable material. From this point, an imagined first-person anecdote alone is not a quality failure.
Earlier flags remain records of the then-current experimental rules, not the new acceptance criterion.
V4 permits creative first-person expression but still respects supplied facts and explicit restrictions;
technical errors and manufactured studies/test results remain quality failures. No training or provider
model modification occurred: this is prompt/workflow design in the standalone lab.


### Agent Platform batch outcome

Four completed polished scripts, eight SDK calls total, requested Gemini3.5Flash/global. No failed stage in this batch.
V2 equipment20.31s, tutorial24.18s; V3 equipment19.72s; owner-directed creative V4 equipment22.14s.
These are exploratory examples, not repeated/blinded evidence of a universal winner. V3's stricter review removed
its explicit invented history but still added an unsolicited comment CTA and kept “only upgrade at the physical limit”.
V2 tutorial retained categorical front-window prohibition and an overpromised professional result; not technically approved.

V4 equipment develops the room/light/audio example and more concrete upgrade situations. Creative freedom did not
force an invented life story; it used an imagined scene and a conversational stance. Material is substantially richer
than the short PCC control. Remaining weaknesses: categorical “only at physical limit”, expensive-camera-in-dark
comparison rhetoric, unsolicited CTA, and “phone noisy at night means you need a bigger sensor” is too deterministic
(exposure, light, processing and the task also matter). The model's own polishing did not reliably catch those issues.
First-person authorial stance remains weaker than requested: much of the text addresses generic “you”.
Do not label this production-ready or fully hallucination-free. The next quality experiment should isolate technical
claim checking from voice polish and test additional topics/repetitions without changing the owner's creative policy.
All eight reserved calls are consumed; no hidden retry batch or provider fallback is launched.

Validation: three Python input-contract tests, eight pure JS tests and JS/Python syntax checks pass.
No Xcode builds, production SDK integration or iPhone Firebase tests were performed in this batch.
