# 10 · Share to universe (multi-network posting) — v30

Decisions for implementation. Source of truth for 6.3, 7.6, 8.1, 8.2 and the posting queue. Prototype: `prototype/cue-exports.js` (sheet + queue) and `screens/8.2_The-send-off.html`.

## 1. Principles
- Finishing the work should feel like relief: one tap, a clear checklist, no surprises.
- **No network logins inside Cue.** The creator is already logged into TikTok, Instagram, YouTube and LinkedIn on the iPhone; Cue hands the file to those apps. Everything runs on device, with no server.
- **One clean, final file.** Exporting happens after the work is done, so every network gets exactly the same video.
- **One clean master.** Every network gets the file made in Cue, never a file re-downloaded from another network, so no TikTok/Instagram watermark can ever appear. Say it once in the sheet: "✓ CLEAN FILE FOR EVERY NETWORK · NO WATERMARKS".

## 2. Vocabulary (two different "captions")
| Term in the UI | What it is | Travels with the video? |
|---|---|---|
| **Captions** (editor, 7.4) | On-screen subtitles burned into the pixels | **Yes, always** |
| **Post text** ("Caption copied") | Description + hashtags typed in the network's upload screen | **No.** TikTok and Instagram no longer accept prefilled text from other apps → Cue copies it to the clipboard for each step |

## 3. Flow
1. **6.3 / 7.6 / 8.1** — every share button reads **Share to universe** (7.6: "Yes — share to my universe").
2. **Pick networks** (`.sheet`, large; close = `Button(role: .close)`): video thumbnail, title, the clean-file line; a grouped list with a checkmark per network: TikTok (pre-selected, "· from your script"), Reels, Shorts, YouTube, LinkedIn. Each row has a mono fit line: "9:16 · 0:52 FITS", "9:16 · POSTS AS A SHORT", or a warning if the video is over that network's limit. Toggle **Also save to Photos** (on). CTA **Share to {n} networks** (yellow, shine; disabled with 0). Under it: "Uses 1 free export · {k} left after this" or "Pro · unlimited exports".
3. **Export once.** One render, **the same file for every network**. The video is final at this point: Cue never crops, trims or changes it at export. Toast "Exported · saved to Photos".
4. **Posting queue**, one network at a time (progress bar of n segments: yellow = current, green = posted, grey = later):
   - Title "Post to {network}", mono "1 OF 3".
   - Checklist (only items that apply): ✓ Caption copied · paste it in {app} (+ the text, written by AI per network in the creator's voice, editable) · ✓ Your captions are in the video · keep auto captions off · ◷ Cover frame 0:03 · music: "Trending sound? Add it in {app}" · ad: "Turn on Paid partnership" + #ad already in the text.
   - **Open {app}** (yellow) → hands off the file. **Post later** (text).
   - On return: **"Posted on {network}?"** · "Welcome back. Cue lights its planet once it's live." · **Not yet** (glass) / **Yes, it's live** (yellow). Only *Yes* counts as SHARED.
   - Close (xmark) during the queue = the rest goes to *later*.
5. **8.2 Send-off** with every network marked *Yes*: one star per network, 350 ms apart, each planet pulses and gets +1; text "SHARED TO 3 NETWORKS" (the lit planets name them); every "+1" is placed in a free spot next to its planet (above, below its label, or beside), never over another label, planet, "YOU" or another "+1". If none was posted: no send-off, toast "Saved · post when you're ready".
6. **Later**: 6.3 shows "POST TO LINKEDIN LATER" under Share; Takes keeps the video in READY for those networks. At most one gentle reminder a week, on Takes only.

## 4. Platform hand-off (iOS)
| Network | Mechanism | User login in Cue | Company setup |
|---|---|---|---|
| TikTok | TikTok **Share Kit** (opens TikTok's editor with the video) | No | Register the app in TikTok for Developers (client key) |
| Reels / Stories | Instagram **sharing to Reels/Stories** (URL scheme + pasteboard) | No | Meta App ID |
| YouTube (Shorts) | System share sheet with the file (YouTube app) | No | — |
| LinkedIn | System share sheet with the file | No | — |
| Photos | PhotoKit (`PHPhotoLibrary`, add-only permission at first save) | — | — |
- **Posting can't be confirmed by Cue.** Networks report at most "handed off", never "published" → the "Posted?" question is the source of truth. Check the current SDK terms before implementing; they change.

## 5. Rules
- **[NEGÓCIO] approved and confirmed by the owner:** free exports are counted **per export, never per network** — one Share to universe to any number of networks = 1 export.
- **When an export is counted:** the moment the file is delivered for the first time — saved to Photos, or loaded into a network app (TikTok editor, Instagram, YouTube, LinkedIn, the system share sheet) — **even if the creator never publishes it**. Once per export: the next networks in the same queue don't count again. A failed render or a cancel **before** delivery doesn't count. Free = 5 videos; then the "Your video is ready" sheet (see 03/09 · Free exports running out).
- Spec per export: 1080×1920, 30 fps, HEVC/H.264, AAC 48 kHz; length checked per network; captions kept inside the common safe zone of the chosen networks.
- Universe: each *Yes* adds +1 to that network's planet for the current year (9.2 scale); one star per video in the universe even if posted to several networks.
- Data (new): `ShareRecord { takeID, network, date, status: posted | later }`; `PostText { takeID, network, text }`.

## 6. Reduce Motion / accessibility
- Sheet and queue: no slide/shine; the send-off shows its final state.
- Each network row is a `Toggle`-like checkbox with label "{Network}, {fit line}"; the queue announces "Step 1 of 3, post to TikTok"; the progress bar is hidden from VoiceOver.

## 7. In practice: what the creator does in each app
| Network | Cue opens… | The creator finishes there |
|---|---|---|
| TikTok | TikTok's editor with the clip (Share Kit; the file is saved to Photos first) | optional sound/effects → Next → paste text, cover, privacy → Post |
| Reels | Instagram's Reels editor with the clip | optional audio/text → Next → paste caption, cover → Share |
| YouTube Shorts | YouTube's upload screen (system share sheet) | paste title, audience "not made for kids" → Upload (vertical & short → Short) |
| LinkedIn | the post composer with the video (system share sheet) | paste text → Post |
- Coming back: iOS shows the **"◀ Cue"** breadcrumb (top-left) in the network app; Cue catches `scenePhase == .active` and the queue shows **"Posted on {network}?"**. TikTok Share Kit can also report completed/cancelled; use it to pre-select the answer, but always ask.
- ~30–60 s per network. The checklist mirrors exactly what to tap inside each app.

## 8. Every situation, and what Cue does (no dead ends)
| Situation | Cue's answer |
|---|---|
| Network app not installed | Row shows "Not installed · Get it" (App Store link); if picked anyway, that step offers **Save to Photos and post later** |
| Logged out / wrong account in the network app | Nothing to fix in Cue; checklist line "Check you're on the right account" appears when the app reports more than one account is possible (always for LinkedIn/YouTube) |
| Creator cancels inside the network app | Back in Cue → "Posted?" → *Not yet* (pre-selected when TikTok reports cancelled) → stays "Post to {network} later" |
| Clipboard overwritten before pasting | **Copy again** on the step |
| Leaves Cue mid-queue / app killed / phone locked | Queue is saved (`ShareQueue`, on device). Next launch: a card on Scripts and Takes **"Continue posting · 2 of 3 · Reels"**; closing it keeps the items as *later* |
| Comes back hours/days later | Same card; "Posted on TikTok?" still asked for the step that was open |
| Taps *Yes* by mistake | In 6.3, the network line has **Undo "posted"** for 24 h (long-press the SHARED chip) |
| Wants to change the video before the next network | "Edit first" in the step → editor → Done brings the creator back to the same step; the next export uses the new version and doesn't use another free export |
| Video too long for a network | Row warns "Over 3:00 for Shorts" and can't be selected; footnote "Shorten it in the editor to post there". Cue never trims at export |
| Not enough storage to export | Before exporting: "Needs 180 MB · free up space" + Try again; nothing is lost |
| Photos permission denied (needed for TikTok/Save) | Step shows "Allow Photos to send to TikTok" + Open Settings; other networks continue |
| Export fails | "Couldn't export · Try again"; the free-export count only moves after a successful export |
| Offline | Export works; the network apps handle upload when online. Step line: "You're offline · the app will upload when you're back" |
| Out of free exports | "Your video is ready" sheet (03/09 · Free exports running out) |
| Sponsored ad | Step adds "Turn on Paid partnership" + #ad in the text |
| Music in the video | Step adds "Using trending sound? Add it in {app}; Cue's music is royalty-free" |
| Reduce Motion / VoiceOver | No slides or shine; queue announces "Step 2 of 3, post to Reels"; every button ≥ 44 pt |

## 9. Explaining the multi-network posting (first times only)
- When the creator picks **2 or more networks**, the first **2 times** the queue starts with a short page in the same sheet: **"Posting to {n} networks"**, with three numbered lines:
  1. **Cue opens each app.** Your video is already loaded and the post text is copied.
  2. **You post there.** Paste the text, pick the cover, tap Post.
  3. **Tap ◀ Cue to come back.** Top left of the screen. Cue takes you to the next network.
  Below them, the order as mono chips ("TIKTOK › REELS › LINKEDIN") and the CTA **Start with {first network}**. After that the page is skipped.
- On every step, above **Open {app}**, a highlighted note (yellow 10 % tint + 1 pt yellow ring, 15 pt semibold, a "◀ Cue" chip): **"After posting, tap ◀ Cue at the top left. We'll open {next network} next."** — last step: "After posting, tap ◀ Cue at the top left to finish."
- A single network never shows the explainer.

## 10. 8.1 actions — one job each
| Control | What it does | Counts a free export |
|---|---|---|
| **Share to universe** (yellow) | Pick networks → guided posting queue | Yes (1 per video) |
| **Save video** (glass) | Saves the clean file to Photos only — for posting later or keeping | Yes |
| Share icon in the toolbar (glass, `ShareLink`) | The system share sheet: AirDrop, WhatsApp, Messages, Mail, Files, Drive… | Yes |
- "Other apps" is removed: it was the system share sheet with an unclear name. "Also save to Photos" stays only as the toggle inside Share to universe.

## 11. Prototype coverage (what you can tap in `Cue App v30`)
| Built in the prototype | Where |
|---|---|
| Share to universe sheet (multi-select, fit lines, clean-file line, Also save to Photos, export count) | 8.1 → Share to universe |
| Explainer "Posting to {n} networks" (first 2 times, ≥2 networks) | after Share to {n} networks |
| Queue step: checklist, **Copy again**, "When it's posted, tap ◀ Cue", **Edit first**, **Post later**, Open {app} | each step |
| Hand-off screen with the iOS **◀ Cue** breadcrumb (stands in for the network app) | after Open {app} |
| "Posted on {network}?" Yes / Not yet | on return |
| Multi-star send-off, +1 per planet, collision-free labels | 8.2 |
| **Continue posting** card (after closing mid-queue or Edit first) → reopens the queue at the same step; ✕ moves the rest to *later* | 3.2 · 6.2 · 6.3, above the tab bar |
| "POST TO {NETWORK} LATER" on the take | 6.3 |
| Out of free exports → "Your video is ready" → calm Pro → export | APP DATA › FREE EXPORTS › None left |
| Save video / toolbar share icon (system share sheet) | 8.1 |
| Documented only (build in the app): Undo "posted" (24 h), Not installed row, Over-limit trim, storage/permission/offline lines, ad & music checklist lines | §8 |

## 12. Development phases for the hand-off (decided)
**Facts (TikTok for Developers):** an iOS app must already be published on the App Store to pass TikTok's review; apps in development aren't approved. Before that, **Sandbox** mode lets you test Share Kit with up to 10 TikTok accounts without review. Review needs a demo video recorded in Sandbox; expect ~1–2 weeks. Meta (Instagram Reels/Stories sharing): check the current requirements before Phase B.

| Phase | Hand-off | What the creator sees |
|---|---|---|
| **A · Launch (v1.0)** | **System share sheet for every network** (`UIActivityViewController` / `ShareLink` with the file). No approvals needed | Step button **Send to {app}** → the iOS share sheet opens → checklist line "In the share sheet, tap {app}" |
| **B · After approval (v1.x update)** | TikTok **Share Kit** (opens TikTok's editor) and Meta **Reels/Stories sharing**; YouTube and LinkedIn stay on the share sheet | Same queue; for TikTok/Reels the button opens the editor directly and the "tap {app}" line disappears |

**During development (before launch):**
1. First task of the share feature: an on-device spike — one sample video through the share sheet to TikTok, Instagram, YouTube and LinkedIn; record what each app opens.
2. Create the TikTok developer app, a Sandbox with Share Kit, and test with your own accounts (≤ 10). Keep it behind a feature flag (`shareKitEnabled = false` in v1.0).
3. Prepare the review package: privacy policy and terms URLs (verified), app description, demo video of the Sandbox flow.

**Right after launch:** submit TikTok (and Meta) for review → when approved, ship the update that flips the flag. The queue, ◀ Cue, "Posted?" and export counting don't change.
