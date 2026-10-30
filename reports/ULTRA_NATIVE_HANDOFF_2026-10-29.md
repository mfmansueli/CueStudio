# Ultra native integration — checkpoint, 29 October 2026

Status: WORK IN PROGRESS, NOT BUILD-VALIDATED, NOT INSTALLED. Owner requested saving all work before session credits run out.

## Resume here

Checkout: /Users/iagoxavierdelima/.codex/worktrees/pcc-offline-review/CueStudio
Branch: codex/firebase-script-quality. Previous verified/pushed lab commit: e7c448c1.
Remote: git@github.com:mfmansueli/CueStudio.git.
Do not work in the main checkout or another Claude worktree. Other work continues in .claude/worktrees/editor-refinement-8.
Main has other merged app changes; compare/rebase carefully before final native delivery, preserving those changes.

## Owner decisions

Bring the Gemini/Firebase Ultra experiment into the actual iPhone app. Keep Apple local/PCC available.
Use generous developed drafts, then editorial polish; 20–30 seconds or longer acceptable. Automatic duration is informational.
A time-target comparison was discussed but NOT yet run. Explicit chosen duration still matters.
My Cue Voice should imagine for the creator: first-person everyday stories and invented scenes are welcome editable draft material.
Do not sanitize imagination away. Technical errors, manufactured studies/results/credentials remain problems.
Profile and current prompt should guide voice, perspective, audience and genre; prompt wins over habitual opening/CTA.

Proposed monetization (NOT implemented): 5 lifetime free exports and 5 separate welcome Ultra scripts; Apple AI free on compatible devices;
paid monthly/annual unlimited exports plus 30 Ultra scripts per month, additional consumable packs. No final product IDs/prices agreed.
Cloud quota/accounting must be server-validated; a local counter is only a lab guard, not production commerce.

Owner authorized privacy adaptation based on Google's actual promises. Need separate Ultra disclosure/explicit consent, revoke control,
policy and App Store privacy declarations. Do not promise zero retention, no external processing, or Apple-only AI for Ultra.
Google Cloud does not train on customer data without permission/instruction; caching and abuse logging can apply.
Global endpoint does NOT guarantee EU-only processing. Provider-specific conditions matter; do not conflate Developer API and Agent Platform.

## Existing web lab (verified)

Isolated cue-script-ai-lab, owner account already signed in. Owner personally linked billing; Blaze verified. Agent Platform enabled.
Developer API also remains enabled in console, but current test code explicitly selects AgentPlatformBackend(global), no fallback.
Cloud trial credits may cover eligible Agent Platform use, not Gemini Developer API. Do NOT upgrade underlying trial account/card automatically.
No real/private user profile has been sent so far: web benchmarks use frozen synthetic fixtures only.
Local server: python3 tools/quality/firebase_lab/server.py --config build/firebase-quality/config.json, loopback127.0.0.1:8768.
Exec session32923 was running. Config/debug token/results are ignored under build/firebase-quality; never commit/print credentials.
Persistent web ledger agent-platform-budget.json is EXHAUSTED at8/8 top-level SDK calls. Do not silently reset it.
Four polished outputs (8 calls), requested Gemini3.5Flash, ~19.72–24.18sec. Saved in research_notes/Firebase script quality/agent-platform-2026-10-29.json.
V4 creative equipment:370 words,22.14sec, richer than PCC; still overstates bigger sensor as necessary for night noise and adds habitual CTA.
No blanket quality/factual-accuracy approval. Three Python + eight JS tests passed at e7c448c1.
Estimated per polished script from observed usage at current global price: USD0.031–0.043, includes thinking, not verified invoice.

## New unvalidated native implementation

Added FirebaseAI and FirebaseAppCheck products from existing firebase-ios-sdk12.19.2 package in pbxproj. No build settings changed.
Only shared SDK boundary imports these in Debug. Production Firebase project/TelemetryManager remains unchanged.

New files:
- Managers/ScriptAI/Ultra/UltraLabPrompt.swift: pure draft/review instructions and context assembled from ScriptRequest.
  Uses AIRequestPolicy.prepare(.privateCloud) to strip raw examples/excerpts/approvedSamples, VoiceBriefBuilder preferences6000units.
  Language, platform, prompt, explicit time target and optional inspiration included. No fabricated privacy guarantee.
  CURRENT LIMITATION: not an exact port of web content-first v4; full voice preferences included in both stages. Need align/test deliberately.
  Inspiration currently String(describing: brief), should replace with explicit scoped fields before real use.
- Managers/ScriptAI/Ultra/UltraLabService.swift (#if DEBUG): named FirebaseApp CueUltraLab, AgentPlatform global, Gemini3.5Flash,
  draft+plain-text polish,4096token cap,90s per call, STOP/nonempty required, no retries/fallback. Reads Documents/UltraLab-GoogleService-Info.plist.
  Config must have project cue-script-ai-lab and matching bundleID. No config added to repository or app bundle.
  A local UserDefaults counter ultraLab.sdkCalls.v1 caps at10 SDK calls (5 polished generations), including failures.
  NOT a production credit ledger; native experimental cap separate from exhausted web ledger. No native calls have run.
- Managers/ScriptAI/Ultra/UltraLabAppCheckFactory.swift (#if DEBUG): debug provider only for named lab FirebaseApp; nil for other apps.
  Need verify interaction with existing default app/provider initialization. Never weaken enforcement.
- Screens/Scripts/Ultra/UltraLabViewModel.swift (#if DEBUG): explicit consent, async cancellation, retains failed-review draft separately,
  successful final text only after second stage. No telemetry of content. NEED fix stale service draft if later request fails before new draft.
- Screens/Scripts/Ultra/UltraLabView.swift (#if DEBUG): native Form under Settings > Privacy & AI data > AI Scripts Ultra · Lab;
  consent disclosure, exact payload preview, prompt editor, draft/review progress, output and save into ordinary script library.
  Uses real ScriptStarter.factory for language/profile/platform. No ordinary dock or Find Inspiration routing switched yet.
  Save currently can duplicate and should confirm/save once; mark factCheck true where appropriate and preserve request language.
- PrivacyView.swift: Debug-only NavigationLink to native lab. Release UI unchanged.

Native UI uses Palette.ink/ink2 on native Form; no new colors. Still needs rendered contrast validation.
New English consent strings and Allow Google processing are NOT yet added/localized in20 languages. Technical Debug status strings
are verbatim developer diagnostics. Need finish localization and service protocol/test injection before final delivery.
Need ensure cancellation/revocation stops future stage dispatch and does not label stale/partial output final.
Need tests for payload minimization, exact prompt/literals, informative vs explicit duration, no-consent zero requests,
review failure handling, cancellation, persistent budget, duplicate taps/save; UI consent guard.

## Build state

scripts/check-project.sh PASSED after package-product additions (pbxproj, configs, schemes/plans).
scripts/build.sh app launched exec67584 but was waiting behind Claude Release build in editor-refinement-8.
Our log build/logs/build-app.log remained EMPTY; no native Swift compile validation occurred.
At checkpoint stopped ONLY our queued script88306 and lockf88475 with TERM; did NOT interrupt other session's build.
Re-run scripts/build.sh app when resuming; do not rely on previous check. Follow only pertinent tests per owner; no Full rerun requested.
Final check-warnings required before declaring complete. Use scripts only, shared queue, no extra DerivedData or simulators.

## Firebase iOS registration state / browser

Registered Apple app in cue-script-ai-lab: nickname Cue Ultra iOS Lab, bundleID com.cuestudioteleprompter.
Console wizard visibly reached Download configuration step. No new terms accepted, no security/provider permissions changed.
Clicked download GoogleService-Info.plist; no file found in Downloads. Configuration file NOT obtained/copied to device yet.
Browser tab5 at Firebase settings registration wizard may have been automatically closed at turn end; inventory before continuing.
Attempted unsupported locator.expectDownload (failed), then correct documented tab.playwright.waitForEvent('download') before click;
this timed out30s and RESET the CUA JS kernel. All prior JS bindings are lost. Reinitialize with one allowed entry call.
Browser is same IAB id2. Native registration exists, do not create duplicate apps. Navigate general settings and retrieve plist again.
Download API documented: tab.playwright.waitForEvent('download'), click, await result.path(). May need alternate console config view.
Firebase native App Check debug provider/token is NOT registered. Registration is security-sensitive and CUA requires action-time consent
for expanded access; prepare the concrete isolated app/token first then ask if required. Previous token authorization was for web lab app.
Never log/copy debug token into Git or public reports. App Check enforcement must not be disabled.
Need copy verified lab plist to Documents/UltraLab-GoogleService-Info.plist using devicectl after authorized Debug install.
No new native build installed, no phone Firebase generation yet. Owner authorizes Iago phone test/install, Mansuelli for manual testing.

## Source references (verified official)

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention
- https://firebase.google.com/support/privacy
- https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
- https://firebase.google.com/docs/ai-logic/get-started
- https://firebase.google.com/docs/ai-logic/faq-and-troubleshooting

Remaining release work is substantial: app workflow/provider selection, actual consent integration/policy across20languages, production
attestation, secure credits/entitlements/packs, app-store metadata and review. Current scope is native experimental test, not release migration.
