# Third-party notices

## YUCIHighPassSkinSmoothing (evaluated; not adopted, no code copied)

Skin's first smoothing (engine 1, `SkinSmoothingFilter`; Quick edit › Skin keeps it for the edits made with it) was built after evaluating
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
Today's smoothing (engine 2, `SkinBeautyFilter`), the face light and the anti-shine owe nothing to it either: an edge-aware evening after the
published guided filter of He, Sun and Tang, and morphology, written with Core Image's built-in filters.

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

## Sample libraries (recorded instruments and sounds in the music library and the sound effects)

The music library's tracks are composed by Cue and played, offline, on recorded instruments from free sample libraries; most sound
effects are made from recordings in free libraries (`tools/music/`, `AUDIO_LIBRARY.md` §1–§2). The rendered files ship in the app
(`Cue Studio/SupportFiles/Sounds/`); the libraries themselves do not. Settings › Acknowledgements lists the ones in use with their license
(`SoundSource`; legal text in `Cue Studio/SupportFiles/Licenses/CC0-1.0.txt`). Every library is CC0 (owner's decision, 29 October 2026):
nothing in the app or in a video made with it owes credit, and Cue credits them anyway.

| Library | Author | License | Used for |
|---|---|---|---|
| [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE) | Versilian Studios | CC0 1.0 | Music, effects |
| [Versilian Community Sample Library (VCSL)](https://github.com/sgossner/VCSL) | Versilian Studios | CC0 1.0 | Music (its Steinway and Knight upright pianos too), effects |
| [Virtuosity Drums](https://github.com/sfzinstruments/virtuosity_drums) | Versilian Studios and Karoryfer Samples, played by Austin McMahon | CC0 1.0 | Music, effects |
| [Swirly Drums](https://github.com/sfzinstruments/karoryfer.swirly-drums) | Karoryfer Samples | CC0 1.0 | Music |
| [Spanish Classical Guitar](https://freepats.zenvoid.org) | FreePats project | CC0 1.0 | Music |
| [Kenney sound packs](https://kenney.nl) (Interface, UI, RPG, Casino) | Kenney | CC0 1.0 | Effects |

## Fonts for other scripts (downloaded on demand, not in the app)

Cue ships only a manifest of these families (`Cue Studio/SupportFiles/FontPacks.json`, made by `tools/fonts/make_manifest.py` from
`tools/fonts/packs.py`): each file is downloaded from the google/fonts repository at commit `6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec` the first time a video uses
it, checked against its SHA-256 and kept on the iPhone. Every family is licensed under the SIL Open Font License 1.1 (the license text Cue shows is
`Cue Studio/DesignSystem/Fonts/inter-OFL.txt`'s, from its "This Font Software is licensed" on), shown in Settings › Acknowledgements › Fonts for other scripts. The fonts are used unmodified.

| Family | Script | License | Copyright |
|---|---|---|---|
| Zen Kaku Gothic New | japanese | SIL OFL 1.1 | Copyright 2022 The Zen Project Authors (https://github.com/googlefonts/zen-kakugothic) |
| M PLUS Rounded 1c | japanese | SIL OFL 1.1 | Copyright 2016 The Rounded M+ Project Authors. |
| Zen Maru Gothic | japanese | SIL OFL 1.1 | Copyright 2021 The Zen Maru Gothic Authors (https://github.com/googlefonts/zen-marugothic) |
| Dela Gothic One | japanese | SIL OFL 1.1 | Copyright 2020 The Dela Gothic Project Authors (https://github.com/syakuzen/DelaGothic) |
| Reggae One | japanese | SIL OFL 1.1 | Copyright 2020 The Reggae Project Authors (https://github.com/fontworks-fonts/Reggae/), all rights reserved. |
| Mochiy Pop One | japanese | SIL OFL 1.1 | Copyright 2020 The MochiyPop Project Authors (https://github.com/fontdasu/Mochiypop) |
| Zen Old Mincho | japanese | SIL OFL 1.1 | Copyright 2021 The Zen Old Mincho Project Authors (https://github.com/googlefonts/zen-oldmincho) |
| Yomogi | japanese | SIL OFL 1.1 | Copyright 2020 The Yomogi Project Authors (https://github.com/satsuyako/YomogiFont), all rights reserved. |
| Hachi Maru Pop | japanese | SIL OFL 1.1 | Copyright 2020 The Hachi Maru Pop Project Authors (https://github.com/noriokanisawa/HachiMaruPop) |
| M PLUS 1 Code | japanese | SIL OFL 1.1 | Copyright 2021 The M+ FONTS Project Authors (https://github.com/coz-m/MPLUS_FONTS) |
| Noto Sans SC | chineseSimplified | SIL OFL 1.1 | (c) 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'. |
| ZCOOL KuaiLe | chineseSimplified | SIL OFL 1.1 | Copyright 2018 The ZCOOL KuaiLe Project Authors (https://github.com/googlefonts/zcool-kuaile) |
| ZCOOL QingKe HuangYou | chineseSimplified | SIL OFL 1.1 | Copyright 2018 The ZCOOL QingKe HuangYou Project Authors (https://www.github.com/googlefonts/zcool-qingke-huangyou) |
| ZCOOL XiaoWei | chineseSimplified | SIL OFL 1.1 | Copyright 2018 The ZCOOL XiaoWei Project Authors (https://www.github.com/googlefonts/xiaowei) |
| Ma Shan Zheng | chineseSimplified | SIL OFL 1.1 | Copyright 2018 The MaShanZheng Project Authors (https://github.com/googlefonts/mashanzheng) |
| Long Cang | chineseSimplified | SIL OFL 1.1 | Copyright 2018 The LongCang Project Authors (https://github.com/googlefonts/longcang) |
| Zhi Mang Xing | chineseSimplified | SIL OFL 1.1 | Copyright 2018 The ZhiMangXing Project Authors (https://github.com/googlefonts/zhimangxing) |
| Noto Sans TC | chineseTraditional | SIL OFL 1.1 | (c) 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'. |
| Huninn | chineseTraditional | SIL OFL 1.1 | Copyright 2025 The Huninn Project Authors (https://github.com/justfont/Huninn) |
| Noto Serif TC | chineseTraditional | SIL OFL 1.1 | (c) 2017-2024 Adobe (http://www.adobe.com/). |
| LXGW WenKai TC | chineseTraditional | SIL OFL 1.1 | Copyright 2024 The LXGW WenKai Project Authors (https://github.com/lxgw/LxgwWenkaiTC) |
| Iansui | chineseTraditional | SIL OFL 1.1 | Copyright 2025 The Iansui Project Authors (https://github.com/ButTaiwan/iansui) |
| Black Han Sans | korean | SIL OFL 1.1 | Copyright 2015 The Black Han Sans Project Authors (https://github.com/zesstype/Black-Han-Sans) |
| Do Hyeon | korean | SIL OFL 1.1 | Copyright 2018 The Do Hyeon Project Authors |
| Gasoek One | korean | SIL OFL 1.1 | Copyright 2022 The Gasoek Project Authors (https://github.com/JAMO-TYPEFACE/Gasoek) |
| Jua | korean | SIL OFL 1.1 | Copyright 2018 The BM JUA Project Authors |
| Bagel Fat One | korean | SIL OFL 1.1 | Copyright 2022 The Bagel Fat Project Authors (https://github.com/JAMO-TYPEFACE/BagelFat) |
| Nanum Myeongjo | korean | SIL OFL 1.1 | Copyright © 2010 NHN Corporation. All rights reserved. Font designed by FONTRIX. |
| Nanum Pen Script | korean | SIL OFL 1.1 | Copyright © 2010 NHN Corporation. All rights reserved. Font designed by Sandoll Communications Inc. |
| Gaegu | korean | SIL OFL 1.1 | Copyright 2018 The Gaegu Project Authors |
| Cairo | arabic | SIL OFL 1.1 | Copyright 2009 The Cairo Project Authors (https://github.com/Gue3bara/Cairo) |
| Almarai | arabic | SIL OFL 1.1 | Copyright (c) 2019 by Almarai. All rights reserved. |
| Reem Kufi | arabic | SIL OFL 1.1 | Copyright 2015-2022 The Reem Kufi Project Authors (https://github.com/aliftype/reem-kufi). |
| Lemonada | arabic | SIL OFL 1.1 | Copyright 2011 The Lemonada Project Authors (https://github.com/Gue3bara/Lemonada) |
| Changa | arabic | SIL OFL 1.1 | Copyright 2018 The Changa Project Authors (https://github.com/eliheuer/changa-vf) |
| Lalezar | arabic | SIL OFL 1.1 | Copyright 2015 The Lalezar Project Authors (https://github.com/BornaIz/Lalezar) |
| Marhey | arabic | SIL OFL 1.1 | Copyright 2022 The Marhey Project Authors (https://github.com/namelatype/Marhey) |
| Amiri | arabic | SIL OFL 1.1 | Copyright 2010-2022 The Amiri Project Authors (https://github.com/aliftype/amiri). |
| El Messiri | arabic | SIL OFL 1.1 | Copyright 2015 The El Messiri Project Authors (https://github.com/Gue3bara/El-Messiri) |
| Aref Ruqaa | arabic | SIL OFL 1.1 | Copyright 2015-2021 The Aref Ruqaa Project Authors (https://github.com/alif-type/aref-ruqaa), with Reserved Font Name EURM10. |
| Mukta | devanagari | SIL OFL 1.1 | Copyright (c) 2014, Girish Dalvi, Ek Type. All rights reserved. |
| Hind | devanagari | SIL OFL 1.1 | Copyright (c) 2014 Indian Type Foundry (info@indiantypefoundry.com) |
| Baloo 2 | devanagari | SIL OFL 1.1 | Copyright 2019 The Baloo 2 Project Authors (https://github.com/EkType/Baloo2) |
| Teko | devanagari | SIL OFL 1.1 | Copyright 2023 The Teko Project Authors (https://www.github.com/googlefonts/teko) |
| Khand | devanagari | SIL OFL 1.1 | Copyright (c) 2014 Indian Type Foundry (info@indiantypefoundry.com) |
| Yatra One | devanagari | SIL OFL 1.1 | Copyright 2014 The Yatra Project Authors. |
| Rozha One | devanagari | SIL OFL 1.1 | Copyright (c) 2014 Indian Type Foundry (info@indiantypefoundry.com) |
| Martel | devanagari | SIL OFL 1.1 | Copyright (c) 2015 Dan Reynolds. |
| Kalam | devanagari | SIL OFL 1.1 | Copyright (c) 2014 Indian Type Foundry (info@indiantypefoundry.com) |
| Kanit | thai | SIL OFL 1.1 | Copyright 2020 The Kanit Project Authors (https://github.com/cadsondemak/kanit) |
| Prompt | thai | SIL OFL 1.1 | Copyright (c) 2015, Cadson Demak (info@cadsondemak.com) |
| Mitr | thai | SIL OFL 1.1 | Copyright (c) 2015, Cadson Demak (info@cadsondemak.com) |
| Mali | thai | SIL OFL 1.1 | Copyright 2018 The Mali Project Authors (https://github.com/cadsondemak/Mali) |
| Chakra Petch | thai | SIL OFL 1.1 | Copyright 2018 The Chakra Petch Project Authors (https://github.com/m4rc1e/Chakra-Petch.git) |
| Trirong | thai | SIL OFL 1.1 | Copyright (c) 2015, Cadson Demak (info@cadsondemak.com) |
| Itim | thai | SIL OFL 1.1 | Copyright (c) 2015, Cadson Demak (info@cadsondemak.com), Copyright (c) 2014, Pablo Impallari (www.impallari.com/impallari@gmail.com) |
| Sriracha | thai | SIL OFL 1.1 | Copyright (c) 2015, Cadson Demak (info@cadsondemak.com), Copyright (c) 2014, Pablo Impallari (www.impallari.com/impallari@gmail.com) |
| Charm | thai | SIL OFL 1.1 | Copyright 2018 The Charm Project Authors (https://github.com/cadsondemak/charm) |
