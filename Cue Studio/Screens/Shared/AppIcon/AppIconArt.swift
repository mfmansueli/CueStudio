//
//  AppIconArt.swift
//  Cue Studio
//

import SwiftUI

/// An app icon as it looks on the Home Screen, at `size`: the milestone icons from their pictures (`AppIconChoice.previewName`), and
/// Cue's own drawn from the layers of `AppIcon.icon` (the night gradient, the script's lines, two faint outer ones and two between them, and
/// the yellow reading line in the middle with its two arrowheads and glow), since an Icon Composer icon has no picture to show.
struct AppIconArt: View {
    let icon: AppIconChoice
    let size: CGFloat

    /// The corner of a Home Screen icon, for its size.
    static func radius(for size: CGFloat) -> CGFloat { size * 0.225 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius(for: size), style: .continuous)
        Group {
            if let name = icon.previewName {
                Image(name).resizable().scaledToFill()
            } else {
                standard
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(LinearGradient(colors: [Palette.Settings.tileRim, .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
        .accessibilityHidden(true)
    }

    /// `AppIcon.icon`, on its 1024 grid: faint lines round y 232 and 792, lines at y 327 and 627 (480 × 70), the guide at 482 (500 × 60)
    /// with arrowheads in from 160 and 864.
    private var standard: some View {
        Canvas { context, canvasSize in
            let unit = canvasSize.width / 1024
            let rect = CGRect(origin: .zero, size: canvasSize)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Palette.Settings.iconNightTop, Palette.Settings.iconNightBottom]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: canvasSize.height)
            ))
            func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
                CGRect(x: x * unit, y: y * unit, width: width * unit, height: height * unit)
            }
            // The faint outer lines (`lines-faint.png`, at 35%): soft-edged, the top one longer than the bottom one.
            context.drawLayer { faint in
                faint.addFilter(.blur(radius: 12 * unit))
                for (x, y, width) in [(CGFloat(316), CGFloat(203), CGFloat(392)), (336, 763, 352)] {
                    faint.fill(
                        Path(roundedRect: box(x, y, width, 58), cornerRadius: 29 * unit),
                        with: .color(Palette.Settings.iconLines.opacity(0.35))
                    )
                }
            }
            // The script's two lines (`lines.svg`, at 70%).
            for y: CGFloat in [327, 627] {
                context.fill(Path(roundedRect: box(272, y, 480, 70), cornerRadius: 35 * unit), with: .color(Palette.Settings.iconLines.opacity(0.7)))
            }
            var guide = Path(roundedRect: box(262, 482, 500, 60), cornerRadius: 30 * unit)
            guide.addPath(Path { path in
                path.move(to: CGPoint(x: 160 * unit, y: 441 * unit))
                path.addLine(to: CGPoint(x: 248 * unit, y: 512 * unit))
                path.addLine(to: CGPoint(x: 160 * unit, y: 583 * unit))
                path.closeSubpath()
                path.move(to: CGPoint(x: 864 * unit, y: 441 * unit))
                path.addLine(to: CGPoint(x: 776 * unit, y: 512 * unit))
                path.addLine(to: CGPoint(x: 864 * unit, y: 583 * unit))
                path.closeSubpath()
            })
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 40 * unit))
                glow.fill(guide, with: .color(Palette.Settings.iconGuide.opacity(0.55)))
            }
            context.fill(guide, with: .color(Palette.Settings.iconGuide))
        }
    }
}
