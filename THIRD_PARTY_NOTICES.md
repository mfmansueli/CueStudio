# Third-party notices

## YUCIHighPassSkinSmoothing (evaluated; not adopted, no code copied)

Skin Smoothing (Quick edit › Adjust) was built after evaluating
[YuAo/YUCIHighPassSkinSmoothing](https://github.com/YuAo/YUCIHighPassSkinSmoothing) (version 1.4, last commit 26 Feb 2020),
a Core Image implementation of the photo editors' *high-pass skin smoothing* (frequency separation).

**What was inspected, and why it is not a dependency**

| | YUCIHighPassSkinSmoothing | What Cue needed |
|---|---|---|
| License | MIT (© 2016 Yu Ao) | MIT is fine to use |
| Distribution | CocoaPods only (no Swift Package), Objective-C, depends on the `Vivid` pod | Swift Package or no dependency; no ObjC |
| Kernels | Three `.cikernel` files in the legacy Core Image Kernel Language (`CIColorKernel(string:)`), deprecated since iOS 12 | Core Image built-ins or Metal; nothing deprecated |
| Faces | None: it smooths the whole picture | Faces and skin only; eyes, brows, lips, hair, beard and background untouched |
| Tone | Its "skin tone curve" lifts the mid-tones (120 → 146): it **whitens** | No whitening, no change of the average |
| Video | Still pictures; no temporal handling | Steady from frame to frame (no flicker), the same in the preview and the export |

**What Cue did instead.** Only the idea is shared: separate the skin's tone from its texture with a blur and work on the green channel's high-pass
detail. Everything else is Cue's own, written with Core Image's built-in filters (no custom kernel, no second rendering engine): Vision's face
landmarks to find the skin and take out the eyes, brows and lips; a skin-tone gate measured on each face; a masked blur that counts only skin;
edge-aware coring of the texture (small detail is softened, edges and hair are kept); a capped strength. See `Cue Studio/Managers/Editing/SkinSmoothing/`
and `FrameLook`'s documentation. None of the reference's source (`.cikernel` or Objective-C) is copied, and its constants are not used.

Because the technique, and not the code, was taken from it, no part of the MIT license has to travel with Cue's binary; the license is kept here
anyway, with the evaluation, so the origin of the idea is on record.

```
The MIT License (MIT)

YUCIHighPassSkinSmoothing

Copyright (c) 2016 Yu Ao https://yuao.me

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## GL Transitions (adapted: six transitions rewritten with Core Image; no code copied)

Quick edit › Transitions offers Zoom, Blur, Flash, Push, Punch and Wipe. Their motion follows six transitions of
[gl-transitions/gl-transitions](https://github.com/gl-transitions/gl-transitions) (reference commit
`c06c4905958446b7da2d121b12942495e18c99c0`, 15 Oct 2026). Cue draws them with Core Image's built-in filters
(`Cue Studio/Managers/Editing/TransitionDrawing.swift`); no GLSL is copied. Because the formulas and constants are taken from there,
the work is treated as an adaptation and the MIT notice ships with the app (Settings › Acknowledgements; file
`Cue Studio/SupportFiles/Licenses/gl-transitions-MIT.txt`).

| Cue | Source file | Author (file header) | License | What differs in Cue |
|---|---|---|---|---|
| Zoom | `CrossZoom.glsl` | rectalogic (ported by gre); based on glfx.js `zoomblur.js`, © 2011 Evan Wallace, MIT | MIT | `CIZoomBlur` on each side, centered (9:16), then a dissolve on the same exponential ease |
| Blur | `LinearBlur.glsl` | gre (Gaëtan Renaudeau) | MIT | Gaussian blur, triangular strength, edges clamped |
| Flash | `Overexposure.glsl` | Ben Zhang | MIT | Exposure (up to 1.6 stops, sin² curve) on the blend, since adding in Core Image adds alpha too |
| Push | `Directional.glsl` | Gaëtan Renaudeau | MIT | Cubic ease in-out instead of `directional-easing` (it finished the move in a third of the cut) |
| Punch | `zoomInOut.glsl` | OllyOllyOlly | MIT | Zoom capped at 1.5× so a face never shows its pixels |
| Wipe | `directionalwipe.glsl` | gre | MIT | `CILinearGradient` mask, leaning left to right |

Not used: `InvertedPageCurl` (BSD-3-Clause) and `StereoViewer` (BSD-2-Clause). Studied and not adopted (no code copied, nothing ships):
VideoLab (MIT), MTTransitions (MIT, depends on MetalPetal), MetalPetal (MIT; its examples are non-commercial), Cabbage (MIT) and
VideoEditorKit (MIT). The evaluation is in `reports/editor-references.md`.

```
The MIT License (MIT)

Copyright (c) 2017-present gl-transitions contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## MediaPipe Face Mesh V2 (Eye Contact's face landmarks: Google's weights, converted for Core ML; Apache 2.0, ships with the app)

✦ Smart › Eye Contact finds each eye's outline and iris, frame by frame, with the face landmark model of MediaPipe's Face Landmarker
(Face Mesh V2, 478 points with both irises; model card: <https://storage.googleapis.com/mediapipe-assets/Model%20Card%20MediaPipe%20Face%20Mesh%20V2.pdf>,
"Licensed under Apache License, Version 2.0").

**What ships.** `Cue Studio/Managers/Editing/EyeContact/FaceMeshV2.mlpackage` (2.9 MB): `face_landmarks_detector.tflite` from
`face_landmarker.task` (<https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task>,
sha256 `64184e22…6e0bc9ff`), converted TFLite → ONNX (tf2onnx) → PyTorch (onnx2torch) → Core ML program in float16, input taken as a
256 × 256 image. Reproduce with `tools/eyecontact/landmarks.py`; `tools/eyecontact/verify_landmarks.py` compares it with MediaPipe's
own runtime on a video. Weights sha256 of the shipped model: `03487a67…6cf935ba1` (`EyeContactEngine.weights`). Only the landmark model
ships: Vision finds the face, and the face detector and blendshape models of the `.task` are not used.

**License.** Apache 2.0: the license and the notice of what was changed travel with the app in Settings › Acknowledgements
(`SupportFiles/Licenses/mediapipe-Apache-2.0.txt`, `CodeCredit`), as section 4 asks.

**Data.** Trained by Google; its model card documents the evaluation across regions, skin tones and genders, and warns of jitter in
poor light, which Cue smooths over time (`EyeTrackSmoother`). No dataset ships with Cue.

## Locked Gaze (Eye Contact's rules: read, rewritten; MIT, no code copied)

[albond/locked-gaze](https://github.com/albond/locked-gaze) @ `ee65b15a6e8bde26d6b363d465e3f10049e63a2d` (MIT) is an open macOS
host for NVIDIA Maxine's eye contact models (which it doesn't ship and Cue doesn't use). Its frame pipeline shows how Maxine decides and
blends: a blink when the eye's opening falls under 0.65 of its running mean, the correction fading with a quintic between 20° and 30° of
gaze or head turn, never changing more than 0.1 a frame, a One-Euro filter on the landmarks, and only the difference blended in, over
the old and new lids' outlines grown and feathered. Cue's `EyeGazePlan`, `EyeTrackSmoother` and `EyeRedraw` follow those rules in
their own code (both ways in time, since a recording is already filmed); the credit and its license are in Settings › Acknowledgements.

**Drawing.** Cue's own (`EyeRedraw`, prototyped in `tools/eyecontact/prototype.py`): the upper lid raised by a smooth lift, the iris moved
as one piece of its own pixels with what the lids hid completed from the iris itself, the white filled from the eye's own white, the
cornea's reflections kept in place. No model generates pixels.

**Patents (not legal advice).** A search found Intel's US10423830, US10664949 and US11024002 (eye-region warping by a learned vector
field: close to the first Eye Contact, which used Hsu's warping network and was removed) and Snap's US11468544 (an eye texture built from
iris extraction and sclera segmentation in video: close to Cue's drawing). Their claims weren't read; a freedom-to-operate check is
advised before release.

**Looked at and not used.**

| Project | What it is | Why it isn't in Cue |
|---|---|---|
| [chihfanhsu/gaze_correction](https://github.com/chihfanhsu/gaze_correction) @ `7cc76e4` (BSD-3) | "Look at Me!" (Hsu et al. 2019): a warping network on a 64 × 48 eye crop | Shipped in Eye Contact's first version and removed: on the iPhone its per-frame flow made lids and lashes wobble (owner's test, 18/10/2026; +0.56 px of flow a frame on a real take against +0.18 now), and its training data's terms are not stated |
| [KypMon/coreml-eye-contact](https://github.com/KypMon/coreml-eye-contact) @ `e9d5ae5` | Hsu's model converted to ONNX | No license |
| [zhengyuf/STED-gaze](https://github.com/zhengyuf/STED-gaze) | ST-ED (NVIDIA) gaze redirection | GPL/NVIDIA source licenses, weights unlicensed, trained on GazeCapture |
| [GazeNeRF](https://github.com/AlessandroRuzzi/GazeNeRF), [GazeGaussian](https://github.com/ucwxb/GazeGaussian), [RTGaze](https://github.com/hengfei-wang/RTGaze) | 3D-aware redirection | No license; trained on ETH-XGaze (CC BY-NC-SA); far too slow for a phone |
| [HzDmS/gaze_redirection](https://github.com/HzDmS/gaze_redirection), interpGaze | GAN redirection | Trained on Columbia Gaze (non-commercial) |
| [zhangqianhui/GazeAnimationV2](https://github.com/zhangqianhui/GazeAnimationV2) | Eye inpainting | Research-only training data; regenerates the whole eye, which flickers |
| LivePortrait | Face re-synthesis | Its face detector is non-commercial; re-synthesizes the whole face |
| [GazeFlow](https://github.com/CVI-SZU/GazeFlow) (MIT code) | Gaze redirection with ETH-XGaze models | ETH-XGaze forbids commercial use |
| dlib's 68-point predictor | Landmarks | iBUG 300-W's terms exclude commercial use |
| [GazeLock](https://github.com/devkoriel/gazelock), [CursorGaze](https://github.com/Sahil-Bhoite/CursorGaze) | Swift/Core ML projects | Not working yet, or no model files to verify |
| NVIDIA Maxine / Broadcast, Apple FaceTime, CapCut, Captions, Descript | Products | Closed; studied only through their published descriptions and output |
