# Cue — App Icon (5a · Motion)

## Xcode (asset catalog)
Drag `AppIcon.appiconset` into `Assets.xcassets` (replace the existing AppIcon).
- `AppIcon-1024.png` — default, 1024×1024, full-bleed square, **RGB with no alpha** (App Store–safe). iOS applies the rounded mask; don't round the corners.
- `AppIcon-Dark-1024.png` — dark appearance, transparent background (the system adds its dark backdrop).
- `AppIcon-Tinted-1024.png` — tinted appearance, grayscale on black (the system applies the tint).

Xcode 14+ generates every smaller size from the single 1024 image.

## Icon Composer (iOS 26 Liquid Glass)
Import the three layers in `IconComposer-layers` in this order — background, lines, guide — to get per-layer glass, specular highlights and the Clear/Tinted modes.

## Source
`SVG/` has the editable vector master and the two foreground layers. Palette: background #26262A → #050506, lines #F4F2EE at 22% / 55%, guide #FFD60A.
