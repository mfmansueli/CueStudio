//
//  PaletteContrastTests+PreviewGestures.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// Over the preview while a finger is on it: the "All captions" ↕ label over a dragged caption (words and arrow on the toasts'
    /// opaque pill, 4.5:1) and the lock on a picked, locked photo or video (a black glyph on its white disc, an icon that informs,
    /// 3:1). Both are opaque, so the picture under them doesn't count; light and dark, with and without Increase Contrast.
    @Test func theCaptionScopeAndTheLockReadOverAnyPicture() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(userInterfaceStyle: style).modifyingTraits { $0.accessibilityContrast = contrast }
                let words = ColorContrast.ratio(opaque(Palette.ink, traits), opaque(Palette.Toast.fill, traits))
                #expect(words >= ColorContrast.textMinimum, "All captions, style \(style.rawValue), contrast \(contrast.rawValue): \(words)")
                let lock = ColorContrast.ratio(opaque(Color.black, traits), opaque(Color.white, traits))
                #expect(lock >= ColorContrast.componentMinimum, "lock, style \(style.rawValue), contrast \(contrast.rawValue): \(lock)")
            }
        }
    }

    private func opaque(_ color: Color, _ traits: UITraitCollection) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: nil)
        return ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
    }
}
