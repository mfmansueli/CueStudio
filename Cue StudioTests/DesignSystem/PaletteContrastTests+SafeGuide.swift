//
//  PaletteContrastTests+SafeGuide.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// The editor's safe zone guide over the worst pictures, white and black: the clear area's edge (white on its dark halo, the halo
    /// against the picture: a line that informs, 3:1) and the label ("TikTok · approximate", `ink` on its plate, 4.5:1) where it sits,
    /// over the shade of a covered zone or straight on the picture, with and without Increase Contrast.
    @Test func theSafeGuideReadsOverAnyPicture() {
        let pictures = [ColorContrast.RGB(red: 0, green: 0, blue: 0), ColorContrast.RGB(red: 1, green: 1, blue: 1)]
        for picture in pictures {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
                let halo = guideColor(Palette.Editor.safeGuideHalo, traits, over: picture)
                let line = ColorContrast.ratio(guideColor(Palette.Editor.safeGuideLine, traits, over: halo), halo)
                #expect(line >= ColorContrast.componentMinimum, "line on its halo over \(picture): \(line)")
                let alone = ColorContrast.ratio(guideColor(Palette.Editor.safeGuideLine, traits, over: picture), picture)
                #expect(max(alone, ColorContrast.ratio(halo, picture)) >= ColorContrast.componentMinimum, "guide over \(picture)")
                let shaded = guideColor(Palette.Editor.safeGuideShade, traits, over: picture)
                for under in [picture, shaded] {
                    let plate = guideColor(Palette.Editor.safeGuidePlate, traits, over: under)
                    let words = ColorContrast.ratio(guideColor(Palette.ink, traits, over: plate), plate)
                    #expect(words >= ColorContrast.textMinimum, "guide label over \(under), contrast \(contrast.rawValue): \(words)")
                }
            }
        }
    }

    /// A token as it shows in `traits`, laid over `background` when it's translucent.
    private func guideColor(_ color: Color, _ traits: UITraitCollection, over background: ColorContrast.RGB) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let solid = ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return ColorContrast.composite(solid, alpha: Double(alpha), over: background)
    }
}
