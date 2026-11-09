//
//  PaletteContrastTests+FirstCelebration.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// D4's two places: Takes' "✦ FIRST STAR" (`TakeFirstStarPill`, `accText`) on a poster's pill over the worst frame (white) and a black one, and
    /// on the list's chip surface; the send-off's icon row (`SendOffIconRow`): its name, its line and "✓ In use" on its card. With and without
    /// Increase Contrast.
    @Test func theFirstStarPillAndTheSendOffsIconRowRead() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            for frame in [ColorContrast.RGB(red: 1, green: 1, blue: 1), ColorContrast.RGB(red: 0, green: 0, blue: 0)] {
                let pill = Self.firstStarColor(Palette.Takes.posterPill, traits, over: frame)
                let value = ColorContrast.ratio(Self.firstStarColor(Palette.accText, traits, over: pill), pill)
                #expect(value >= ColorContrast.textMinimum, "FIRST STAR on a poster, contrast \(contrast.rawValue): \(value)")
            }
            let chip = Self.firstStarColor(Palette.surface2, traits)
            #expect(ColorContrast.ratio(Self.firstStarColor(Palette.accText, traits), chip) >= ColorContrast.textMinimum, "FIRST STAR in the list")
            let card = Self.firstStarColor(Palette.surface, traits)
            for (name, token) in [("name", Palette.ink), ("line", Palette.ink2), ("In use", Palette.successText)] {
                let value = ColorContrast.ratio(Self.firstStarColor(token, traits), card)
                #expect(value >= ColorContrast.textMinimum, "\(name) on the icon row, contrast \(contrast.rawValue): \(value)")
            }
        }
    }

    /// `color` as it shows in `traits`, over `background` (black by default) where it is translucent.
    private static func firstStarColor(
        _ color: Color, _ traits: UITraitCollection, over background: ColorContrast.RGB = ColorContrast.RGB(red: 0, green: 0, blue: 0)
    ) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb = ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return ColorContrast.composite(rgb, alpha: Double(alpha), over: background)
    }
}
