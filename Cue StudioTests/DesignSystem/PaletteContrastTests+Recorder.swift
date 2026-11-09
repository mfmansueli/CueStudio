//
//  PaletteContrastTests+Recorder.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// The recommendation's change lines ("Frame 4:5 → 9:16") over the brightest camera feed too: the field's name in `aiTextStrong`,
    /// the values in `ink`, and the "This take" mark (`inkSoft` on its solid `surface2` pill), with and without Increase Contrast.
    @Test func theRecommendationsLinesReadOverABrightFeed() {
        let white = ColorContrast.RGB(red: 1, green: 1, blue: 1)
        for traits in Self.recorderTraits {
            for fill in [Palette.Camera.recommendationTop, Palette.Camera.recommendationBottom] {
                let card = Self.recorderResolved(fill, traits, over: white)
                for token in [Palette.aiTextStrong, Palette.ink] {
                    let measured = ColorContrast.ratio(Self.recorderResolved(token, traits, over: card), card)
                    #expect(measured >= ColorContrast.textMinimum, "a change line over white: \(measured)")
                }
            }
            let pill = Self.recorderResolved(Palette.surface2, traits)
            #expect(ColorContrast.ratio(Self.recorderResolved(Palette.inkSoft, traits, over: pill), pill) >= ColorContrast.textMinimum, "This take")
        }
    }

    /// The recorder's storage line ("About 9 min left in 4K") on its solid capsule: the text in `ink`, the drive in `warnText`.
    @Test func theStorageLineReadsOnItsCapsule() {
        for traits in Self.recorderTraits {
            let capsule = Self.recorderResolved(Palette.surface, traits)
            #expect(ColorContrast.ratio(Self.recorderResolved(Palette.ink, traits, over: capsule), capsule) >= ColorContrast.textMinimum, "the line")
            let drive = Self.recorderResolved(Palette.warnText, traits, over: capsule)
            #expect(ColorContrast.ratio(drive, capsule) >= ColorContrast.componentMinimum, "the drive")
        }
    }

    private static let recorderTraits = [UIAccessibilityContrast.normal, .high].map { contrast in
        UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
    }

    /// `color` as it shows in `traits`, over `background` (black by default) where it is translucent.
    private static func recorderResolved(
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
