## Editor motion: Follow face, Stabilize, Track, speed curves, Reverse and Beats

Six Quick edit tools that read the video's motion, all on the iPhone (Vision, AVFoundation, Accelerate; nothing leaves the device, no paid service). Preview and export go through the same compositor, so they show the same frames.

### What's in

- **Motion analysis in the background** (`MotionAnalysisService`, `MotionAnalyzer`): every recording the edit plays is analyzed once at low priority (faces and bodies 10×/s, the camera's motion every frame on background tiles away from the people, combined by what most tiles agree on). It stops when Cue goes to the background or the iPhone gets hot and resumes from where it stopped. Kept next to the recording (`.cuemotion`, versioned, out of backups, deleted with it); edits never depend on it.
- **Format › Follow face**: the Fill crop follows the creator's face like a calm camera operator (dead zone, top speed, zero-lag smoothing), with Calm / Natural / Quick.
- **Stabilize** (clip): Gentle / Standard / Strong, the least zoom that hides the edges, a corridor so jolts never show an edge, "Use on every clip".
- **Track** (text, graphic, media): put the item on the object, tap Track; Vision follows it both ways and the path becomes editable keyframes in one undo step.
- **Speed › Curve**: Hero, Bullet, Ramp up/down, Montage, Flash in/out and a custom curve with draggable points; the picture is stretched in 30 steps a second and the sound is rendered along the curve offline (time-pitch with "Keep voice pitch", varispeed without), so it neither steps, drops nor clicks.
- **Reverse** (clip): the clip's stretch written backwards (picture and sound) as its own file; Reverse again plays forward.
- **Beats** (music from Files only): beats found on the iPhone (spectral flux, autocorrelation tempo, dynamic-programming beats), ticks on the music track, Snap to beats, Move cuts to the beats, Cut the video on every 1/2/4 beats.

### Measured on an iPhone 15 Pro (copies of the owner's takes; details in `reports/editor-motion-report.md`)

| | |
|---|---|
| Motion analysis | 0.25–0.28× the video's length (8–9 ms a frame), +30–55 MB, thermal state nominal throughout |
| Follow face | export time unchanged (3.8 → 3.7 s for 34 s at 1:1); the crop moves at most 7 px a frame |
| Track | 6 ms a frame; a face followed for 6 s, 21 px (p50) from the detected face in a 1080 px frame |
| Stabilize | a real frame shaken by hand-like wobble: 2.63 → 0.44 px of shake a frame (Standard, 3.5% zoom) |
| Speed curve | export 6.1 → 8.0 s with Hero on 10 s (sound rendered along the curve) |
| Reverse | 10 s of 1080p in 2.2 s, 16 MB |
| Beats | 3 minutes in 1.6 s (124 BPM clicks → 123.0 BPM, 371 beats) |

### Tests

Unit (Swift Testing): analyzer, service, paths, tracker, curves, beats, reverse, editor view models; real exports for Follow face, Stabilize, curves (frame timing and sound) and Reverse; UI `EditorMotionUITests`; device suites `MotionAnalysisDeviceTests`, `EditorMotionDeviceTests`.

**Not run in this branch (left for the testing phase):** `scripts/check-warnings.sh`, the Full plan, the UI suites (only `EditorMotionUITests` ran, 2/2), installing on the iPhone. The Fast plan passed after the fixes (see the report).

**Not validated:** stabilization on a genuinely shaky take (the owner's are steady; validated on a real frame shaken in a known way), curve sound on real speech, Track on non-face objects, beats on real music, 60 fps and other devices' videos, the iPhone 15 (A16).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
