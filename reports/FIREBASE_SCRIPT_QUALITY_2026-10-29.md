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
