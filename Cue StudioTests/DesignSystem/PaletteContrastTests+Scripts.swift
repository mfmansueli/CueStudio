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

    /// The dock's chips, each in the colour of what it does, on the dock's violet glass laid over `surface2` (lighter than the sky under it):
    /// a setting's words and menu mark on its light glass, the AI's on its violet. Their hairlines are decorative: the words say what each is.
    @Test func theDocksChipsReadOnTheirGlass() {
        let chips: [(name: String, fill: Color, inks: [(name: String, color: Color)])] = [
            ("a setting's chip", Palette.Scripts.heroChipGlass, [("ink", Palette.ink), ("ink2", Palette.ink2)]),
            ("the AI's chip", Palette.Scripts.heroChipAI, [("aiTextStrong", Palette.aiTextStrong), ("aiText", Palette.aiText)]),
        ]
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            let dock = Self.solid(Palette.Scripts.dockBase, traits, over: Self.solid(Palette.surface2, traits))
            for chip in chips {
                let fill = Self.solid(chip.fill, traits, over: dock)
                for ink in chip.inks {
                    let value = ColorContrast.ratio(Self.solid(ink.color, traits, over: fill), fill)
                    #expect(value >= ColorContrast.textMinimum, "\(ink.name) on \(chip.name), contrast \(contrast.rawValue): \(value)")
                }
            }
        }
    }

    /// The Drafts group's purple title on the Scripts list, on the night, its cards and the interstellar sky.
    @Test func theDraftsTitleReadsOnTheList() {
        for contrast in [UIAccessibilityContrast.normal, .high] {
            let traits = UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { $0.accessibilityContrast = contrast }
            for surface in [Palette.bg, Palette.surface, Palette.surface2, Palette.Sky.interstellarBg] {
                let background = Self.solid(surface, traits)
                let value = ColorContrast.ratio(Self.solid(Palette.Scripts.draftText, traits), background)
                #expect(value >= ColorContrast.textMinimum, "DRAFTS on \(surface), contrast \(contrast.rawValue): \(value)")
            }
        }
    }

    /// `color` as it shows in `traits`, over `background` (black unless said) where it is translucent.
    private static func solid(
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
