# Approved screens · Cue App v30

These are the **only** screens of v30: exactly the ones you see when you open `prototype/Cue App v30.dc.html`. Anything outside this list (older versions, test boards, options files, `design/cue-v29`, `design/cue-universe-v27`, `Cue App v2x`) is **history. Do not implement it.**

How to view: serve `prototype/` (`python3 -m http.server`) and open `Cue App v30.dc.html`. The left panel lists every screen (*Jump to any screen*) and what to tap.

**How a screen is built:** `prototype/screens/<ID>_<name>.html` is the base layout. At runtime, `CueBoard30.dc.html` and the `cue-*.js` scripts add the final layer: the shared sky, glass navigation buttons, translucent cards, the Scripts dock, sheets, editor tools, states and toasts.
**The running prototype is the visual truth.** If the static HTML and the running prototype differ, the running prototype wins.

| ID | Screen | File | Tab bar |
|---|---|---|---|
| 1.1 | Welcome | screens/1.1_Welcome-every-creator-has-a-universe.html | — |
| 1.2 | Your universe (topics) | screens/1.2_Your-universe-topics-become-worlds.html | — |
| 1.3 | First voyage (platform) | screens/1.3_Your-first-voyage-pick-a-galaxy.html | — |
| 1.4 | First script in your voice | screens/1.4_Your-first-script-in-your-voice.html | — |
| 1.5 | Give it a voice (permissions) | screens/1.5_Give-it-a-voice-permissions-in-the-story.html | — |
| 1.6 | Practice run | screens/1.6_Practice-run-record-or-not.html | — |
| 1.7 | Your first star | screens/1.7_Your-first-star.html | — |
| 2.1 | My Cue Voice · creator type | screens/2.1_My-Cue-Voice-creator-type.html | — |
| 2.2 | My Cue Voice · topics | screens/2.2_My-Cue-Voice-topics-your-colors.html | — |
| 2.3 | My Cue Voice · audience | screens/2.3_My-Cue-Voice-audience.html | — |
| 2.4 | My Cue Voice · tone | screens/2.4_My-Cue-Voice-tone.html | — |
| 2.5 | Does this sound like you? | screens/2.5_Does-this-sound-like-you.html | — |
| 3.1 | Scripts · empty (new account) | screens/3.1_Scripts-first-visit.html | ✓ |
| 3.2 | Scripts (scripts on top, AI dock at the bottom) | screens/3.2_Scripts.html | ✓ |
| 3.3 | Need an idea | screens/3.3_Need-an-idea.html | — |
| 3.4 | Create for (platform) | screens/3.4_Create-for-platform.html | — |
| 3.5 | Start a video (+) | screens/3.5_Start-a-video.html | — |
| 3.6 | Logbook | screens/3.6_Logbook.html | — |
| 4.1 | Script page | screens/4.1_Script-page-AI-writing-in-your-voice.html | — |
| 4.2 | Editing a script (AI on a selection) | screens/4.2_Editing-a-script-AI-on-selection.html | — |
| 4.3 | Pick a hook | screens/4.3_Pick-a-hook.html | — |
| 4.4 | Improve this script | screens/4.4_Improve-this-script.html | — |
| 5.1 | Countdown | screens/5.1_Countdown-a-ring-of-stars.html | — |
| 5.2 | Recorder · Selfie | **CueRecorder30.dc.html** (native component, mode selfie) | — |
| 5.3 | Recorder · Studio | **CueRecorder30.dc.html** (native component, mode studio) | — |
| 6.1 | Pick your best take | screens/6.1_Pick-your-best-take-Cue-picks-a-star.html | — |
| 6.2 | Takes | screens/6.2_Takes.html | ✓ |
| 6.3 | Selected video | screens/6.3_Selected-video.html | — |
| 7.1 | Opening the editor | screens/7.1_Opening-the-editor.html | — |
| 7.2 | Editor (Edit · Audio · Text · Captions · Filters · ✦ Smart · Cover) | screens/7.2_Editor-close-to-v26.html | — |
| 7.3 | Text styles | screens/7.3_Text-styles-free-fonts-and-orb-sliders.html | — |
| 7.4 | Caption styles | screens/7.4_Caption-styles-size-orb.html | — |
| 7.5 | Sound | screens/7.5_Sound-voice-music-and-clean-up.html | — |
| 7.6 | Is it ready to post? | screens/7.6_Is-it-ready-to-post.html | — |
| 8.1 | Share (ready to travel) | screens/8.1_Ready-to-travel.html | — |
| 8.2 | The send-off | screens/8.2_The-send-off.html | — |
| 8.3 | Milestone unlocked | screens/8.3_Milestone-unlocked.html | — |
| 9.1 | Profile | screens/9.1_Profile.html | ✓ |
| 9.2 | Your universe | screens/9.2_Your-universe.html | ✓ |
| 9.3 | My Cue Voice (full page) | screens/9.3_My-Cue-Voice.html | ✓ |
| 10.1 | Send a comment to Cue | screens/10.1_Send-a-comment-to-Cue.html | — |
| 10.2 | Is this right? | screens/10.2_Is-this-right.html | — |
| 10.3 | Draft in your voice | screens/10.3_Draft-in-your-voice.html | — |
| 10.4 | Comment card in the editor | screens/10.4_Comment-card-in-the-editor.html | — |
| 11.1 | Settings | screens/11.1_Settings.html | ✓ |
| 11.2 | Prompter settings | screens/11.2_Prompter-settings-orb-sliders.html | — |
| 11.3 | Personalize | screens/11.3_Personalize-sky-orb.html | — |
| 11.4 | Cue Pro | screens/11.4_Cue-Pro.html | — |

**Sheets and overlays the runtime adds** (no file of their own; see 03-Screen-map and 04-Flows):
- Format sheet (F), Brand brief (B), Import (I).
- Settings sheets: Recording, Remote, Language & Region, Privacy & AI data.
- Recorder ••• More.
- Editor tool panels: Edit, Filters, ✦ Smart, Cover.
- The My Cue Voice tip and sheet (08).
- The star → script transition.
- Empty states: APP DATA › New account in the side panel.

**Names that are history:** some file names still say "orb" or "close-to-v26". The orb visuals are gone. Sliders use the simple slider in 02-Tokens §6, and the runtime already shows it.
