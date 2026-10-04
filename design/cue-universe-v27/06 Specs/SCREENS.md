# Cue Studio v27 — Screen map

Each screen exists as an image in `03 Screens — PNG @3x/<id>.png` and as live HTML in `04 Screens — HTML source/<id>.html`. Open the HTML in a browser to see the motion.

**Phase key:**
- **L** = launch
- **U1** = first update
- **Later** = after the first update

**"v26"** names the screen or behaviour this replaces. Keep the v26 logic and data unless the notes say otherwise.

---

## 0 · System boards

| ID | Board | What it defines |
| --- | --- | --- |
| 0.1 | Concept summary | The idea, the metaphor map and the cautions |
| 0.2 | Icon set v2 · orbit line | 53 icons, grid, motifs, states, the tab orb that travels, alternate app icons |
| 0.3 | Orb controls | Slider anatomy, states, variants, motion, precision and accessibility rules |

---

## 1 · First launch — the voyage begins (L)

Replaces the v26 first-launch flow. It is shown once. The progress bar has 5 segments. **Skip** jumps to the Scripts empty state (3.1), with defaults: no topics and TikTok.

| ID | Screen | Behaviour | Motion (plays once in the app) |
| --- | --- | --- | --- |
| 1.1 | Welcome | "Every creator has a universe to share." **Get started** / **I already use Cue** (sign in, then restore) | Sky dolly-in 2.6 s, constellation stars pop and the line draws, the Cue star ignites (waves + cross flare), words rise from blur, chips pop, then the buttons appear. Shine on the button. |
| 1.2 | Your universe | Pick 1–3 topics, or add your own. They feed My Cue Voice → topics. **Continue** | World birth for each topic: tap ripple → spark flies to the orbit → the orbit draws → the planet pops → the name label shows. The centre star "YOU" has rays and a halo. Particles drift toward the centre. |
| 1.3 | Your first voyage | Pick a platform (galaxy). It sets the format, ideal length and safe zones, the same as v26 "Create for". **Head to TikTok** | Spiral galaxies turn. On tap: the galaxy grows, others dim, the route draws with a comet to it, an arrival flash plays and the format line types in. The YOU star has 3 topic moons. |
| 1.4 | Your first script, in your voice | The AI writes ~15 s in the chosen topic and platform. **Use this script** / **Another** / **I'll write my own**. Without AI or with an unsupported language: a curated script, labelled "TELEPROMPTER PRACTICE". | AI aura on the card, "✦ WRITING FOR TIKTOK" shimmer with dots, words from light section by section, then a reading-line preview, then the buttons rise. |
| 1.5 | Give it a voice | Microphone, then camera, in context. Only button: **Continue** → iOS alert. No Skip and no Not now on this screen. | Microphone orb with level bars and rings; voice particles flow to the camera orb. After "Allow" in the iOS alert: the iris blades open to the live face, a green wave plays and the row shows ✓ Allowed. |
| 1.6 | Practice run | Teleprompter over the front camera, **not recording**. **Record it for real** / **Not now — take me to my studio** | Voice-follow scroll, words light on the horizon, rising particles, the section rail fills, the record button breathes. |
| 1.7 | Your first star | Shown after a real take, or after practice if they chose to record. **Go to my studio** / **Edit this take first** | The take card folds into light → comet to the universe → ignite + 10 particles → a star with a link line to YOU → "FIRST TAKE · TODAY" → the text rises. |

---

## 2 · Complete your voice — later, from Profile (L)

This is v26 My Cue Voice, steps 1–4 plus the preview, restyled. Topics picked in 1.2 arrive pre-filled.

| ID | Screen | Notes |
| --- | --- | --- |
| 2.1 | Creator type | "What kind of creator are you?" Single choice, the same options as v26. |
| 2.2 | Topics = your colors | Up to 3. Each one gets a world colour (warm, mint, pink, sky). "Suggested from your scripts". |
| 2.3 | Audience | "Who's watching? The other worlds your videos reach." Plus "Why do they watch you?" (up to 2). |
| 2.4 | Tone | Up to 2 tones with example lines. |
| 2.5 | Does this sound like you? | "A generic AI would say…" compared with "✦ In your voice". Words from light on the voiced version. |

---

## 3 · Scripts & ideas (L, Logbook U1)

| ID | Screen | v26 | Notes |
| --- | --- | --- | --- |
| 3.1 | Scripts, first visit | Scripts empty state | The writing card is always present: "Type or say an idea…" with LET'S CUE! and the platform. Three-layer sky. Tab bar v2 with the active orb. |
| 3.2 | Scripts | Scripts list | **Platform-first filters** (All · TikTok · Reels · Shorts…). The topic shows as a colour dot (auto tag). The writing card stays on top. |
| 3.3 | Need an idea? | "Need an idea? ✦ FROM YOUR TOPICS" | Ideas grouped by topic, each with format and length. |
| 3.4 | Create for | Platform picker | Per-platform frame, safe zones and length goal. |
| 3.5 | Start a video (+) | Plus menu | Let Cue write it · Write it myself · Import text · Answer a comment (Later) · Record without a script. |
| 3.6 | Logbook (U1) | New | Hold to capture an idea by voice; text ideas too; **Shape** turns one into a script. |

---

## 4 · Write a script (L)

| ID | Screen | v26 | Notes and motion |
| --- | --- | --- | --- |
| 4.1 | Script page | Script editor | Hook · Body · CTA with timings, length bar ("✓ FITS · IDEAL 1:00–1:30"), performance cues (pause, smile). **While the AI writes:** the CTA words are written from light, the CTA bar glows and the "✦ Writing in your voice" pill shimmers. |
| 4.2 | Editing a script | Edit mode | AI actions on a selection. Never animate text the user is typing. |
| 4.3 | Pick a hook | Hooks | Current hook and alternatives by type (question, bold claim…). |
| 4.4 | Improve this script | AI tools | Shorter, punchier hook, sound more like me, add CTA, performance cues, simpler words. |

---

## 5 · Record (L)

| ID | Screen | v26 | Notes and motion |
| --- | --- | --- | --- |
| 5.1 | Countdown | Countdown | "LET'S CUE" with 3·2·1 in a **ring of 12 stars** that ignite as the progress arc fills. A flare at the end, and the prompter horizon brightens. Tap anywhere to cancel. Length comes from Prompter settings. |
| 5.2 | Teleprompter (front camera) | Recording | Voice / Steady modes. **Voice-follow:** the current line rests on the horizon, words light as you say them and read lines dim. A section rail on the right shows Hook → Body → CTA. The label under the prompter shows the section and safe area. "✦ FOLLOWING YOUR VOICE" chip. |
| 5.3 | Studio mode (rear camera) | Studio | Large text for reading from a distance. **Compact orb speed pill**, Mirror, remote status. |

---

## 6 · Pick, review & Takes (L)

| ID | Screen | v26 | Notes and motion |
| --- | --- | --- | --- |
| 6.1 | Pick your best take | Take review (K1) | Cue suggests the best take and explains why (fits, no stumbles, pace, eyes on camera). **Record again** / **Use take 2**. Motion: side takes slide in, a violet analysis line scans the middle take, the "✦ Best take" badge pops with a wave and flare, the reason chips pop one by one. |
| 6.2 | Takes | Takes tab | Pipeline TO PICK › IN EDIT › READY › SHARED, an "Up next · post it" card, platform filters. Tab bar v2. |
| 6.3 | Selected video | Selected take | Status track PICK · EDIT · READY · SHARED ✦, actions, free-export counter. |

---

## 7 · Edit (L) — the editor stays close to v26

The editor has **no sky and no particles.** The personality lives in the transitions and the orb controls.

| ID | Screen | v26 | Notes |
| --- | --- | --- | --- |
| 7.1 | Opening the editor | New transition | "Opening your edit": captions written from the script while the timeline assembles (82%). |
| 7.2 | Editor | Editor | Same layout as v26. Toolbar icons are v2 (Edit, Audio, Text, Captions, Filters, Smart). "Captions ready" toast. |
| 7.3 | Text styles | Text tool | **7 styles with free OFL fonts** (Orbit, Logbook, Signal, Launch, Nebula, Comet, Postcard), **Size** and **Glow** orb sliders, colour swatches. The preview glows live as the Glow orb moves. |
| 7.4 | Caption styles | Captions panel | Styles: Cue · Bold (Anton, replaces "Impact") · Clean · Pop · Editorial. Position segmented control. **Size orb (S·M·L·XL)**, and the preview scales with it. Highlight colour, Edit words. |
| 7.5 | Sound | Audio tool | **Your voice** (0–150%, detent at 100%, waveform behind the track), **Music** (0–100%), **Clean up voice** (Off · Light · Strong). Toast: "Music sits under your voice". |
| 7.6 | Is it ready to post? | E3 | Share to social media (primary, shine) · Download · Ready, I'll post later · Not yet. |

---

## 8 · Share & celebrate (L)

| ID | Screen | Notes and motion |
| --- | --- | --- |
| 8.1 | Ready to travel | Export done: no watermark, free exports left, **Share to TikTok** / Save / Other apps. |
| 8.2 | The send-off | The thumbnail folds into light → **comet** along the route → arrival at the platform (flash + waves + cross flare) → "On its way." / "It's now a star in your universe ›". Plays once. |
| 8.3 | Milestone unlocked | Shown at 1, 10, 25 and 50 shares. Light converges, the icon pops with a flare and slow rays. **Use Deep Space** / **Keep my current icon**. Alternate icons from 10 onward need Pro. |

---

## 9 · Profile & your universe

| ID | Screen | Phase | Notes |
| --- | --- | --- | --- |
| 9.1 | Profile | L | v26 Profile plus "YOUR UNIVERSE · 23 SHARED" and progress to the next milestone. My Cue Voice ("✦ WHAT CUE USES") and the plan card. |
| 9.2 | Your universe | U1 | Topics are worlds and every shared video is a star with a line to its platform. Next milestone, Share my universe, year in review (Later). |

---

## 10 · Answer your audience with a video (Later)

| ID | Screen | Notes |
| --- | --- | --- |
| 10.1 | Send a comment to Cue | Share extension from the social app. Vision OCR finds the comment. |
| 10.2 | Is this right? | Confirm the comment text, the author and the platform before writing. |
| 10.3 | Draft in your voice | The comment becomes the next script (words from light). |
| 10.4 | Comment card in the editor | A comment bubble over the video for the first seconds: style, show @name, timing. |

---

## 11 · Settings & Pro (L)

| ID | Screen | v26 | Notes |
| --- | --- | --- | --- |
| 11.1 | Settings | Settings | Your setup card, Recording, Prompter, Remote, General (Language & Region, **Personalize NEW**, Privacy & AI data). **The Appearance row is removed** because the app is dark only. |
| 11.2 | Prompter settings | Prompter section | **Live preview** at the top. Orb controls: Speed (wpm, detent at default, used when not following the voice), Text size (S·M·L·XL; the preview scales), Reading line (Near the camera · Upper third · Middle), Margins (Narrow · Medium · Wide). Follow my voice switch. Countdown orb row (Off · 3 s · 5 s · 10 s). |
| 11.3 | Personalize | New | App icon picker (unlock states), topics and colours, auto-tag switch. **Starry sky orb (Off · Calm · Lively)**, Celebrations and Haptics switches. Everything turns off with Reduce Motion. |
| 11.4 | Cue Pro | Pay sheet | "Take your universe further." The v26 feature list with tags, plus "Every milestone app icon". Yearly $39.99 ($3.33/mo, SAVE 58%) pre-selected, monthly $7.99 or $9.99 (to be decided in App Store Connect), 7 days free. Never sell AI to a device or language that cannot run it. |
