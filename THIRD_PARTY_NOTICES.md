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
