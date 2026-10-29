# Ultra AI native integration — checkpoint, 29 October 2026

Branch `codex/ultra-native-integration` (from `origin/codex/firebase-script-quality` bfccfb08, merged with `main`). Worktree
`.claude/worktrees/ultra-native-integration`. Not merged to `main`; nothing published; no charges enabled.

Supersedes the "New unvalidated native implementation" part of `ULTRA_NATIVE_HANDOFF_2026-10-29.md` (kept for history). Design state:
`DESIGN_PROJECT.md` §56 (and §2, §5.2, §30).

## Owner decisions in this delivery

- 29/10: App Check debug token registered through the official Firebase CLI (owner's choice); the lab's native call cap raised to 30 (owner's choice).
- 29/10: cap raised to 80, then to **300** ("the credits are for testing and improving the tool as much as it takes") for the quality comparison Codex left pending (claim check apart from the voice polish, more topics, Apple
  Intelligence on the same ideas, blind) plus the owner's hand test; ~USD 1 expected, from the Cloud credits (Agent Platform, not the Developer API).
- 29/10: the feature is **Ultra AI** in the UI; the model's brand (Gemini) never appears on screen. Privacy texts name **Google** as the processor
  (App Store 5.1.2(i) requires naming who data is shared with, including third-party AI).
- 29/10: the owner wants to test, on the phone, the same experience a creator will see (real screens, not only the lab).
- 29/10: **5 free exports and 5 free Ultra AI scripts**; the Pro trial gets the 5 free scripts only (no extra Ultra scripts during the 7 days); paid Pro
  adds 30 a month. Built as a **Debug preview** (counts on the iPhone), not a protection of credits. The Pro list only gains the Ultra AI line (the rest
  of the list stays for a later review, as deferred on 15/10).
- 29/10: an **invitation** to Ultra AI from the second use of the AI, linked across the Scripts dock, Find inspiration and My Cue Voice (closed once,
  closed everywhere), with the owner's refined motion standard (layered motion in time with Core Haptics).

## What exists now

| Piece | Where |
|---|---|
| Two-call writer (draft → polish), consent/budget/cancellation checked before each call, typed failures, Console-only logs | `Managers/ScriptAI/Ultra/UltraScriptService.swift` |
| Exact payload (request verbatim, language, platform, format, length policy, Find inspiration angle/opening, literal phrases, brand brief, voice split content/delivery; never examples, excerpts, approved scripts) | `UltraPayload.swift`, `VoiceBriefBuilder.ultraProjection` |
| Instructions (port of the web lab's content-first-v4-reviewed: development, request wins, no habitual CTA, creative licence, careful claims, JSON polish) | `UltraInstructions.swift` |
| Firebase boundary (Debug only): named app `CueUltraLab`, Agent Platform `global`, `gemini-3.5-flash`, App Check debug provider only for that app, data collection off, token auto-refresh off, streaming progress, JSON schema for the polish, error kinds only | `FirebaseUltraClient.swift`, `UltraLabConfiguration.swift`, `UltraLabAppCheckFactory.swift` |
| Product `FirebaseAILogic` (the `FirebaseAI` wrapper emits a rename warning) + `FirebaseAppCheck`, SDK 12.19.2 | `project.pbxproj` |
| Consent, separate from Apple Intelligence; revocable in Settings | `UltraConsentService.swift`, `Screens/Shared/Ultra/UltraConsentSheet.swift` |
| "What Cue sends" with the real text of both calls | `UltraPayloadView.swift`, consent sheet, My Cue Voice › What Cue sends |
| Scripts dock: writer chip (native menu) | `ScriptsDock.swift`, `ScriptStarter.choose/writesWithUltra` |
| Find inspiration: "Draft with Ultra AI" (Draft it now stays Apple Intelligence) | `FindInspirationSheet.swift` |
| Star, page pill, fact-check banner, toast say "Ultra AI"; `Script.draftedBy` | `StarTransitionOverlay`, `ScriptWritingPill`, `FactCheckBanner`, `Script.swift` |
| Lab (Debug): free / ~90 s reference / 60–90 s required, draft + final + changes + tokens, save once with language, format, provenance, fact check | `Screens/Settings/Privacy/UltraLab/` |
| Lab call cap 300 (counted before sending, failures included, never lowered, standard defaults) | `UltraCallBudget.swift` |
| Free scripts + Pro's monthly ones as a Debug preview (5 free for everyone, trial included; +30/month paid; free first; counted only when written) | `UltraAllowance.swift`, `UltraAllowanceService.swift`, `UsagePolicy`, `Models/UltraAllowanceLabels.swift` |
| Used up: the calm Pro for Ultra AI (`PaywallContext.ultra`) on the free plan, a toast in the trial and on paid Pro | `ScriptStarter.showUltraUsedUp`, `PaywallCopy`, `PresentationService.paywall` |
| Pro screen where Ultra AI is offered: "30 Ultra AI scripts a month", "Free to try · 5 exports and 5 Ultra AI scripts included…"; plan card line | `PaywallCopy.visibleBenefits`, `ProMarketing`, `ProfilePlanCard` |
| Invitation from the second AI use (dock line, Find inspiration card, My Cue Voice card; one invitation for all) | `UltraInviteService.swift`, `Screens/Shared/Ultra/UltraInviteCard.swift` |
| Motion: invitation lighting up, fold, ✦ flight to the writer chip, ring, rolling numbers; `HapticPatterns.ultraOn/ultraIgnite` | `UltraMotion.swift`, `UltraStarHop.swift`, `UltraChipRing.swift` |
| Stub client for UI tests (`-uiTestUltra`, `-uiTestUltraAllowed`, `-uiTestUltraReviewFails`, `-uiTestUltraSlow`) | `SupportFiles/Debug/StubUltraClient.swift`, `LaunchOptions` |

Release builds: `UltraLabConfiguration`, `FirebaseUltraClient`, the App Check factory, the stub and the lab are `#if DEBUG`; `ultraAvailable` is false, so no
Ultra UI shows and no Firebase AI code runs. The debug token is read only from the app's Documents (copied by `devicectl`), never bundled or committed.

## WIP fixes asked for (status)

1. Protocol/injection for network-free tests: `UltraModelClient`, `UltraScriptWriting`, fakes in tests.
2. Stale draft after a failed new run: the lab clears the run, failure and draft before each run; the service keeps nothing between runs.
3. Cancellation/revocation stops later stages: `mayContinue(started:)` before each call; tests for both.
4. Duplicate taps/saves: generate disabled while working; save returns the same script on a second tap.
5. Language, metadata, fact check on save: lab save sets platform, type, language, `factCheck`, `draftedBy`; page flow sets `factCheck` + `draftedBy`.
6. Inspiration brief serialization: explicit fields (subject, angle rule, opening rule) — no `String(describing:)`.
7. Development vs voice adaptation: draft gets identity/audience/topics/rules; polish gets delivery (sounds, rhythm, fingerprint, openings/endings).
8. Preferences can't impose a short script or CTA: the usual video length is never sent; "short sentences" is sent as rhythm, never a limit; instructions
   forbid habitual CTAs unless the request asks.
9. Strings in 20 languages: product strings added with `scripts/strings.py` (lab strings are Debug-only, verbatim English).
10. Failures: typed messages, provider text never kept; a failed polish never shows the draft as the script.

## Tests

All on the shared queue (`scripts/build.sh`, `scripts/test.sh`), simulator iPhone 17, 29/10/2026:

- **Unit (197, all pass):** `UltraAllowanceTests` (free/trial/paid counts, free first, preview month, labels, invitation due/closed/reopened, where it
  shows), `UltraScriptServiceTests` (+ counted only once written, nothing sent with none left), `UltraPayloadTests`, `UltraReviewReplyTests`,
  `UltraCallBudgetTests`, `UltraConsentServiceTests`, `ScriptStarterUltraTests` (+ used up → Cue Pro / trial toast, Apple script counts towards the
  invitation), `ScriptPageUltraTests`, `PaywallCopyTests` (+ Ultra line and contexts), `HapticPatternsTests` (+ the chip lights as the ✦ lands), and the
  neighbours `ScriptStarterTests`, `ScriptStarterBriefTests`, `VoiceBriefBuilderTests`, `ScriptDetailViewModelTests`, `ScriptPageViewModelTests`. Two
  earlier Ultra tests were wrong, not the code: a "say exactly" request without the colon the app requires, and a Find inspiration idea sent without the
  angle its brief needs to stand; both fixed.
- **UI:** `UltraAIUITests` 7/7 (dock asks first then writes; invitation asks first then picks Ultra; closing it closes it everywhere; none left → the
  Ultra calm Pro; saying no; Find inspiration; a failed polish). **UISmoke 26/26.**
- **Contrast** (`testCaptureUltraAIScreensForTheContrastAudit`, `…InvitationForTheContrastAudit`, then pixels measured on the rendered PNGs; the
  hierarchy is taken while the invitation still rises, so `audit.py`'s boxes are offset and each new text was measured on its own rectangle): dock
  invitation text 11.9:1, ✦ 5.6:1, "Try it" 6.3:1, × 4.0:1 (control, needs 3:1); Find inspiration card title 13.6:1, body 5.1:1, button 7.9:1; Profile
  "ULTRA AI · 5 OF 5 FREE LEFT" 8.3:1; Pro "30 Ultra AI scripts a month" 17.6:1, its AI tag 8.3:1, Ultra Pro subtitle 6.4:1; permission allowance line
  8.4:1. All new tokens are existing `Palette` text tokens (`aiText`, `ink`, `ink2`, `aiTextStrong`). My Cue Voice's card wasn't captured (the seeded
  profile has no voice); it is the same component and colours as Find inspiration's.
- **Real calls on the iPhone** (`CUE_DEVICE="iago Lima iphone" scripts/test.sh device UltraDeviceTests`, iPhone 15 Pro, `gemini-3.5-flash`, a
  made-up pt-BR personal-finance creator; `tools/ultra/collect.py`, samples in `research_notes/Ultra AI/ultra-device-2026-10-29*.json`): 6 scripts, 12
  of the lab's 30 calls (**18 left**). The marker in the creator's private writing samples appears in none of the prompts sent.

  | Case | Length asked | Words | ≈ s | Draft s | Polish s |
  |---|---|---|---|---|---|
  | Scripts dock (TikTok) | free | 451 | 180 | 11.2 | 9.1 |
  | Find inspiration (Reels) | required 54–66 s | 152 | 61 | 7.5 | 13.3 |
  | Same idea | free (Shorts) | 223 | 89 | 6.7 | 8.5 |
  | Same idea | reference ~90 s | 233 | 93 | 6.9 | 9.6 |
  | Same idea | required 60–90 s | 186 | 74 | 7.1 | 15.1 |

  Reading: the ideas are developed (the dock's three mistakes each get a concrete scene; Find inspiration opens on the brief's opening line and
  follows its angle down to a R$30 transfer on payday); short, speakable sentences; every required length lands inside its range. Weak points, for
  the owner: the creator's phrase ("Bora lá") and a closing question appear in **every** script (both are the synthetic creator's preferences, and
  the polish lists them as changes each time, so across a creator's scripts they could feel formulaic); pop neuroscience stated as fact ("dopamina",
  "química cerebral", "modo de defesa"), which the careful-claims instruction didn't stop and which no fact-check banner flags (not a factual topic);
  one model title without its tilde ("manhas" for "manhãs"); and a "free" length on TikTok gave ~3 min. The first Find inspiration run sent the idea
  without its angle (the test's mistake, not the app's: the app sends the whole brief) and its hook came out muddled; with the angle it is clear.

## Privacy — drafts, NOT published

Facts used (official Google Cloud / Firebase documentation, read 29/10/2026): Google Cloud does not use customer data to train models without permission;
Gemini on Agent Platform may cache inputs/outputs for up to 24 hours (can be disabled at the project level) and may log prompts for abuse monitoring
(exemptions by request); the `global` endpoint can serve the request from any region (it is not an EU-only or data-residency guarantee). No zero-retention
promise is made anywhere.

### Privacy policy — paragraph to add when Ultra AI ships (draft)

> **Ultra AI (optional).** If you turn on Ultra AI and choose it for a script, Cue sends your idea, the platform, format and length you picked, and your
> My Cue Voice preferences (who you are, who you speak to, how you sound) to Google, which runs the AI model, through Firebase (Google LLC). The draft
> it writes is sent back to Google once more to polish it in your voice. Your writing examples, imported excerpts, approved scripts, other scripts,
> videos and audio are never sent. Google does not use this data to train its models without permission; it may keep it in a cache for up to 24 hours
> and log it to detect abuse, and it may process it in any region. Each request also carries your IP address, the app's identity and an App Check
> token that confirms the request comes from Cue. You can turn Ultra AI off at any time in Settings › Privacy & AI data; Apple Intelligence keeps
> working either way. [If accounts/credits ship: add the account identifier and the credit ledger kept on Cue's server.]

The existing sentences "Cue has no server" / "Apple Intelligence, nothing else" must change in the public policy when Ultra AI ships (the app already
switches its own copy when Ultra AI is offered).

### App Store privacy ("nutrition label") — changes to declare when Ultra AI ships (draft)

- **User Content › Other User Content** (the idea and voice preferences sent for a script): collected, purpose **App Functionality**, **not linked** to
  identity (becomes linked if Ultra AI requires an account for credits), **not used for tracking**. Reason to declare: Google may retain it beyond the
  real-time request (cache, abuse logs).
- **Identifiers / Diagnostics:** none added by Ultra AI as long as Firebase data collection stays off for the Ultra app and nothing goes to Analytics
  or Crashlytics (current code). Re-check if a credit account is added (User ID → linked, App Functionality).
- Guideline 5.1.2(i): explicit consent before sending to a third-party AI — the consent sheet does this; keep it in the production build.
- Production App Check must use **App Attest** (DeviceCheck fallback for older devices), never the debug provider.

## Monetization — plan, NOT activated

Owner's decision (29/10): 5 free exports (lifetime, exists today), 5 free Ultra AI scripts (separate balance; the Pro trial has these only), Apple
Intelligence free, paid subscription adds unlimited exports + 30 Ultra AI scripts/month; consumable packs possible later. **What exists now is a Debug
preview of what the creator sees** (`UltraAllowanceService`, UserDefaults, calendar month): it is not a protection and must not ship as one. Requirements
for production (none of this is built):

1. **Server-side ledger** (e.g. Cloud Functions + Firestore): the client never holds the balance of record. A local counter (like the lab's
   `UltraCallBudget`) is only a UI hint.
2. **Generation behind the server**: the Gemini call moves into a callable function that checks App Check (App Attest) and the user's identity,
   reserves one credit, runs draft + polish, **commits** the debit only when a polished script is returned and **releases** it on any failure or
   cancellation (no debit without a finished script).
3. **Idempotency**: every script request carries a client-generated UUID; the function stores its outcome, so a retry or a dropped connection never
   debits twice nor runs twice.
4. **Purchases verified on the server**: StoreKit 2 signed transactions validated with the App Store Server API; subscriptions renewed/expired from
   App Store Server Notifications V2 (monthly grant of 30, no rollover unless decided); consumable packs credited once per transaction id; refunds
   revoke unspent credits.
5. **Identity**: welcome credits bound to an account (Sign in with Apple, or `appAccountToken`), not to the install, so reinstalling doesn't refill them.
6. **Abuse and cost guards**: per-user rate limits, maximum tokens per call, a monthly budget alert on the Google Cloud project.

## Limits and pending

- **A preview, not protection.** The free scripts and Pro's monthly ones are counted in the iPhone's defaults (Debug only). Shipping needs the count on
  a server (per account, behind App Check / App Attest), a production Firebase project and its billing and quotas: none of it exists, and nothing
  here is configured for real users.
- **App Check** runs only with the debug provider, for the lab app, from a token copied to the app's Documents (never in Git or the bundle). Release
  has no Ultra AI at all.
- **The lab's 300 calls** (30, then 80, until the owner raised it): 18 of the first 30 were left after these tests (2 per script, failures included). At the cap
  Ultra AI stops; raising it is the owner's call. The web
  lab's batch of 8 was used earlier and its ledger is untouched.
- **Privacy texts** (policy paragraph, App Store label) are drafts below, not published. No zero-retention promise: Google processes the request
  under its terms.
- **The trial** is read from StoreKit's offer type (`isInFreeTrial`); checked in unit tests, not against a sandbox subscription in its free week.
- **Contrast:** My Cue Voice's invitation wasn't captured (the seeded profile has no voice); it is the same component and colours as Find
  inspiration's, measured above.
- **Pro list:** only the Ultra AI line was added; the other lines still promise things that don't exist (deferred by the owner on 15/10).
- **For the owner's judgement:** the catchphrase and closing question in every script, the unchecked pop-science claims, and the length a "free"
  TikTok script takes (above).

