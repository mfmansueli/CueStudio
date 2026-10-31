//
//  PaletteContrastTests+Notices.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// The notice that stays in place (`NoticeCard`: Photos or the microphone off, an export that failed): its title and line on `surface`, the
    /// "!" disc against the card (an icon that informs, 3:1) and the glyph on the disc, with and without Increase Contrast.
    @Test func aNoticeCardReads() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let card = Self.resolved(Palette.surface, traits)
            let disc = Self.resolved(Palette.Toast.problem, traits)
            #expect(ColorContrast.ratio(Self.resolved(Palette.ink, traits), card) >= ColorContrast.textMinimum, "title, contrast \(contrast.rawValue)")
            #expect(ColorContrast.ratio(Self.resolved(Palette.ink2, traits), card) >= ColorContrast.textMinimum, "line, contrast \(contrast.rawValue)")
            #expect(ColorContrast.ratio(disc, card) >= ColorContrast.componentMinimum, "disc, contrast \(contrast.rawValue)")
            #expect(ColorContrast.ratio(Self.resolved(Palette.Toast.glyph, traits), disc) >= ColorContrast.textMinimum, "glyph, contrast \(contrast.rawValue)")
        }
    }

    /// `color` as it shows in `traits`, over black where it is translucent.
    private static func resolved(_ color: Color, _ traits: UITraitCollection) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb = ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return ColorContrast.composite(rgb, alpha: Double(alpha), over: ColorContrast.RGB(red: 0, green: 0, blue: 0))
    }
}
