//
//  PaletteContrastTests+Scripts.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

extension PaletteContrastTests {
    /// The bar at the start of a script's card on Scripts says its topic (`ScriptRow`): each world's colour is seen on the card behind it,
    /// with and without Increase Contrast.
    @Test func theTopicsBarShowsOnTheScriptCard() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let card = Self.solid(Palette.surface, traits)
            for world in [Palette.World.warm, Palette.World.mint, Palette.World.pink, Palette.World.sky] {
                let value = ColorContrast.ratio(Self.solid(world, traits), card)
                #expect(value >= ColorContrast.componentMinimum, "\(world) on the card, contrast \(contrast.rawValue): \(value)")
            }
        }
    }

    /// The dock's send arrow while Ultra AI writes the next idea (`DockSendArrow`): the white arrow on the violet face is the button's meaning.
    @Test func ultraAIsSendArrowShowsOnItsViolet() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let value = ColorContrast.ratio(Self.solid(Palette.Scripts.ultraSendInk, traits), Self.solid(Palette.Scripts.ultraSend, traits))
            #expect(value >= ColorContrast.componentMinimum, "Ultra AI's arrow, contrast \(contrast.rawValue): \(value)")
        }
    }

    /// `color` as it shows in `traits`, over black where it is translucent.
    private static func solid(_ color: Color, _ traits: UITraitCollection) -> ColorContrast.RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb = ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return ColorContrast.composite(rgb, alpha: Double(alpha), over: ColorContrast.RGB(red: 0, green: 0, blue: 0))
    }
}
