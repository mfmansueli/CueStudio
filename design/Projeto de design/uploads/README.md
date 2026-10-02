# Cue — AppIcon.icon (Icon Composer · iOS 26 Liquid Glass)

Icon 5a · Motion, split into layers for Icon Composer.

## Use in Xcode 26
1. Drag **AppIcon.icon** into the Xcode project navigator (not into Assets.xcassets). Tick your app target.
2. Target → General → App Icons → set the App Icon to **AppIcon** (same name as the file).
3. Delete or rename any old `AppIcon` in Assets.xcassets to avoid a name clash.
4. Build — Xcode renders Default, Dark, Clear and Tinted from the layers.

## Layers (front → back)
| Group | File | Opacity | Glass |
|---|---|---|---|
| Guide | guide.svg (yellow line + arrows, #FFD60A) | 100% | on |
| Guide glow | guide-glow.png (soft yellow glow) | 55% | off |
| Lines | lines-inner.svg (2 white lines, #F4F2EE) | 55% | on |
| Lines fading | lines-outer.png (2 blurred outer lines) | 22% | off |

Background: linear gradient #26262A → #050506, set as the icon fill.

## Light & Dark appearances
The same AppIcon.icon now carries both:
- **Light (default):** background #FFFFFF → #E9E8E4, ink lines #1C1C1E (50% / 20%), guide #F4B400 (a deeper yellow that holds contrast on white).
- **Dark:** the original — background #26262A → #050506, lines #F4F2EE (55% / 22%), guide #FFD60A.

Light files end in `-light`. If Icon Composer doesn't pick up the dark specializations from icon.json, select each group, switch the appearance picker to **Dark**, and swap the image to the matching non-light file (and the fill to the dark gradient).

## Tip
Open **AppIcon.icon** in Icon Composer (Xcode → Open Developer Tool → Icon Composer) to preview the Dark / Clear / Tinted modes and fine-tune glass, shadow and translucency per group. If Icon Composer reports a problem with icon.json, create a new icon there and drop the four files from `Assets/` in the order above — the result is identical.
