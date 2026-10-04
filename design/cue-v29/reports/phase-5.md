## Phase 5 · Recorder — report
Built: ✓ · Warnings: 0 · Tests: unit suite green / ~14 new (`PrompterV29Tests`) · UI: `RecorderV29UITests` and `PrompterUITests` green (the text-window corner test needed the pinch edge under the handle; fixed)

### Done
- **5.2 box and reading line**: while recording the box is 10 pt narrower per side and 16% shorter (`ReadingLayout.isRecording`); a pinch on the right edge moves the reading line (10–50% of the height, `ReadingLinePinch`); everything goes to the session's `PrompterSettings` (`boxWidth`, `boxHeight`, `readingLine`). The compact bar's mode chip no longer truncates ("STEADY 0.7×").
- **5.3 Studio records** (`StudioModeView`, `StudioCameraThumbnail`): rear camera, 64 × 114 pt thumbnail in the corner with a red ring while recording, 78 pt margin so the text is never covered, the same bar as Selfie (`SelfieControlPanel(isStudio:)` with ‹‹ ››), lens remembered and returned when going back to Selfie; without a camera it listens through the meter as before.
- **F3**: no microphone → card "Cue needs the microphone" + Open Settings and Record off; storage full and interruptions end the take and keep it ("Storage full · Take saved", "Interrupted · Take saved", `RecordingEndReason`).
- `-uiTestDemoCamera` (Debug): a camera that records a small real video, so the recorder UI is testable in the Simulator.
- **Removed on request**: the big yellow ball (the flare at the end of the countdown, `CountdownFlare`); the haptic stays.

### Captures
- `5.2_idle.png`, `5.2_recording_compact.png`, `5.2_recording_peek.png`, `5.3_studio_idle.png`, `5.3_studio_recording.png`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| text window resize / reset | 0.3 s | smooth | same |
| Studio thumbnail ring | 0.3 s | ease-out | same |
| compact ↔ full bar (tap) | 4 s hold, then back | spring 0.3 s | fade |
| countdown number | in 0.35 s from 1.35× + blur, out 0.2 s | ease | fade |

### Not matched exactly
- **Studio in the Simulator** shows the camera thumbnail as a "no camera" placeholder (no rear camera there); on a device it is the live image.
- **Pinch on the reading line** is on the right edge (56 pt), not the whole screen, so it never fights the text-window corner and the line's handle.

### Kept from v27 that the board doesn't show
- The Voice Following status line in Studio (`prompter.voiceStatus`), the audio-input pill, This take, Remote in •••, safe zones, Display.

### Next phase starts with
- Takes, review and editor (6.1–6.3, 7.1–7.6).
