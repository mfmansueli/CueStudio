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
