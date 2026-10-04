//
//  PaletteContrastTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

/// The palette against Apple's contrast guidelines (4.5:1 for text, 3:1 for the parts of a control)
/// in the light and the dark appearance, with and without Increase Contrast. Cue's screens follow
/// the iPhone (or Settings › Appearance), so every pair that can show in light is measured there
/// too: no screen turns pale yellow on white. The camera, prompter, review and editor stay dark.
@MainActor
@Suite("Palette contrast")
struct PaletteContrastTests {
    private enum Appearance: CaseIterable, CustomStringConvertible {
        case light, dark, lightIncreased, darkIncreased

        var traits: UITraitCollection {
            let style: UIUserInterfaceStyle = self == .light || self == .lightIncreased ? .light : .dark
            let contrast: UIAccessibilityContrast = self == .lightIncreased || self == .darkIncreased ? .high : .normal
            return UITraitCollection(userInterfaceStyle: style).modifyingTraits { traits in
                traits.accessibilityContrast = contrast
            }
        }

        var isLight: Bool { self == .light || self == .lightIncreased }

        var description: String {
            switch self {
            case .light: "light"
            case .dark: "dark"
            case .lightIncreased: "light + Increase Contrast"
            case .darkIncreased: "dark + Increase Contrast"
            }
        }
    }

    /// What a token looks like in an appearance, over `background` when it's translucent.
    private func rgb(_ color: Color, in appearance: Appearance, over background: ColorContrast.RGB? = nil) -> ColorContrast.RGB {
        let resolved = UIColor(color).resolvedColor(with: appearance.traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let solid = ColorContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return ColorContrast.composite(solid, alpha: Double(alpha), over: background ?? ColorContrast.RGB(red: 0, green: 0, blue: 0))
    }

    private func ratio(_ foreground: Color, on background: Color, in appearance: Appearance) -> Double {
        let base = rgb(background, in: appearance)
        return ColorContrast.ratio(rgb(foreground, in: appearance, over: base), base)
    }

    /// `foreground` on a translucent `tint` laid over `surface`.
    private func ratio(_ foreground: Color, onTint tint: Color, over surface: Color, in appearance: Appearance) -> Double {
        let base = rgb(surface, in: appearance)
        let tinted = rgb(tint, in: appearance, over: base)
        return ColorContrast.ratio(rgb(foreground, in: appearance, over: tinted), tinted)
    }

    private let surfaces: [(name: String, color: Color)] = [
        ("bg", Palette.bg), ("surface", Palette.surface), ("surface2", Palette.surface2),
    ]

    /// Plus the one the tiles sit on, for what only has to be seen.
    private let surfacesWithTiles: [(name: String, color: Color)] = [
        ("bg", Palette.bg), ("surface", Palette.surface), ("surface2", Palette.surface2), ("surface3", Palette.surface3),
    ]

    private let textTokens: [(name: String, color: Color)] = [
        ("ink", Palette.ink), ("ink2", Palette.ink2), ("accText", Palette.accText), ("warnText", Palette.warnText),
        ("dangerText", Palette.dangerText), ("infoText", Palette.infoText), ("successText", Palette.successText),
        ("aiText", Palette.aiText), ("aiTextStrong", Palette.aiTextStrong),
    ]

    private let tertiaryToken: [(name: String, color: Color)] = [("ink3", Palette.ink3)]

    // MARK: - Text

    @Test func textTokensMeetTheTextMinimumOnEverySurface() {
        for appearance in Appearance.allCases {
            for token in textTokens {
                for surface in surfaces {
                    let value = ratio(token.color, on: surface.color, in: appearance)
                    #expect(
                        value >= ColorContrast.textMinimum,
                        "\(token.name) on \(surface.name), \(appearance): \(value.formatted(.number.precision(.fractionLength(2))))"
                    )
                }
            }
        }
    }

    @Test func inkAndSecondaryInkAlsoReadOnTheTileSurface() {
        for appearance in Appearance.allCases {
            for token in [Palette.ink, Palette.ink2] {
                #expect(ratio(token, on: Palette.surface3, in: appearance) >= ColorContrast.textMinimum, "\(appearance)")
            }
        }
    }

    @Test func coloredTextReadsOnItsOwnSoftFill() {
        let pairs: [(name: String, text: Color, tint: Color)] = [
            ("accText", Palette.accText, Palette.accSoft), ("warnText", Palette.warnText, Palette.warnSoft),
            ("infoText", Palette.infoText, Palette.infoSoft), ("dangerText", Palette.dangerText, Palette.dangerSoft),
            ("aiText", Palette.aiText, Palette.aiFill), ("aiTextStrong", Palette.aiTextStrong, Palette.aiFill),
        ]
        for appearance in Appearance.allCases {
            for pair in pairs {
                for surface in surfaces {
                    let value = ratio(pair.text, onTint: pair.tint, over: surface.color, in: appearance)
                    #expect(value >= ColorContrast.textMinimum, "\(pair.name) on its fill over \(surface.name), \(appearance): \(value)")
                }
            }
        }
    }

    // MARK: - Fills with text on them

    @Test func labelsOnTheBrightFillsAreReadable() {
        for appearance in Appearance.allCases {
            #expect(ratio(Palette.accInk, on: Palette.acc, in: appearance) >= ColorContrast.textMinimum, "accInk on acc, \(appearance)")
            #expect(ratio(Palette.accInk, on: Palette.warn, in: appearance) >= ColorContrast.textMinimum, "accInk on warn, \(appearance)")
            #expect(ratio(.white, on: Palette.dangerFill, in: appearance) >= ColorContrast.textMinimum, "white on dangerFill, \(appearance)")
            #expect(ratio(Palette.bg, on: Palette.ink, in: appearance) >= ColorContrast.textMinimum, "a selected chip, \(appearance)")
            #expect(ratio(.white, on: Palette.neutralAction, in: appearance) >= ColorContrast.textMinimum, "white on neutralAction, \(appearance)")
            // v26 controls: the selected chip and the selected segment, with the text they carry.
            #expect(ratio(Palette.chipOnInk, on: Palette.chipOn, in: appearance) >= ColorContrast.textMinimum, "the selected chip, \(appearance)")
            #expect(ratio(Palette.ink, on: Palette.segmentOn, in: appearance) >= ColorContrast.textMinimum, "the selected segment, \(appearance)")
            #expect(ratio(Palette.ink, on: Palette.fill, in: appearance) >= ColorContrast.textMinimum, "an unselected chip, \(appearance)")
        }
    }

    /// The light appearance's hero cards are solid violet with night content: the text a card shows
    /// (ink, secondary ink, the yellow and violet signals) has to read at both ends of the gradient.
    @Test func theHeroCardsReadWithTheirNightContentOnTheLightVioletFill() {
        for fill in [("heroTop", Palette.heroTop), ("heroBottom", Palette.heroBottom)] {
            #expect(ratio(Palette.ink, on: fill.1, in: .dark) >= ColorContrast.textMinimum, "ink on \(fill.0)")
            #expect(ratio(Palette.ink2, on: fill.1, in: .dark) >= ColorContrast.textMinimum, "ink2 on \(fill.0)")
            #expect(ratio(Palette.accText, on: fill.1, in: .dark) >= ColorContrast.textMinimum, "accText on \(fill.0)")
        }
    }

    /// The selected chip also has to stand out from the surface it sits on, as an outline would (3:1).
    @Test func theSelectedChipStandsOutFromEverySurface() {
        for appearance in Appearance.allCases {
            for surface in surfaces {
                #expect(ratio(Palette.chipOn, on: surface.color, in: appearance) >= ColorContrast.componentMinimum, "\(surface.name), \(appearance)")
            }
        }
    }

    /// Night glass (bars, floating controls) over the app's background: every text token reads on it.
    @Test func textReadsOnNightGlass() {
        for appearance in Appearance.allCases {
            for token in textTokens {
                let value = ratio(token.color, onTint: Palette.glassFill, over: Palette.bg, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "\(token.name) on night glass, \(appearance): \(value)")
            }
        }
    }

    // MARK: - Parts of controls

    @Test func tertiaryInkIsAtLeastAVisibleOutlineOnEverySurface() {
        for appearance in Appearance.allCases {
            for surface in surfacesWithTiles {
                let value = ratio(Palette.ink3, on: surface.color, in: appearance)
                #expect(value >= ColorContrast.componentMinimum, "ink3 on \(surface.name), \(appearance): \(value)")
            }
        }
    }

    @Test func theSwipeToRecordKeepsItsWhiteLabelReadable() {
        for appearance in Appearance.allCases {
            #expect(ratio(.white, on: Palette.accAction, in: appearance) >= ColorContrast.textMinimum, "white on accAction, \(appearance)")
        }
    }

    // MARK: - Light screens that used to assume dark

    /// The prompt box: the title sits where the golden light is brightest (34%), the caption and the
    /// description where it is dimmer (13%), and the field is sunk into it. In light the secondary
    /// ink is held to the text minimum everywhere on the card.
    @Test func thePromptBoxReadsOverItsGoldenWash() {
        for appearance in Appearance.allCases {
            for base in [Palette.surface, Palette.surface2] {
                let card = rgb(base, in: appearance)
                let bright = rgb(Palette.acc.opacity(0.34), in: appearance, over: card)
                let dim = rgb(Palette.acc.opacity(0.13), in: appearance, over: card)
                #expect(ColorContrast.ratio(rgb(Palette.ink, in: appearance, over: bright), bright) >= ColorContrast.textMinimum, "the title, \(appearance)")
                if appearance.isLight {
                    #expect(ColorContrast.ratio(rgb(Palette.ink2, in: appearance, over: dim), dim) >= ColorContrast.textMinimum, "the caption, \(appearance)")
                }
                let field = rgb(Palette.insetField, in: appearance, over: dim)
                for token in [Palette.ink, Palette.ink2] {
                    let text = rgb(token, in: appearance, over: field)
                    #expect(ColorContrast.ratio(text, field) >= ColorContrast.textMinimum, "text in the field, \(appearance)")
                }
            }
        }
    }

    /// The panels that stand in for the keyboard in the script editor.
    @Test func theScriptEditorsPanelReadsInBothAppearances() {
        for appearance in Appearance.allCases {
            for token in textTokens {
                let value = ratio(token.color, on: Palette.editorPanel, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "\(token.name) on the panel, \(appearance): \(value)")
            }
            #expect(
                ratio(Palette.laneGhostBorder, on: Palette.editorPanel, in: appearance) >= ColorContrast.componentMinimum,
                "a dashed outline, \(appearance)"
            )
        }
    }

    @Test func settingsSheetsOverTheCameraReadInBothAppearances() {
        for appearance in Appearance.allCases {
            for token in textTokens {
                let value = ratio(token.color, on: Palette.sheetGlass, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "\(token.name) on the glass sheet, \(appearance): \(value)")
            }
        }
    }

    @Test func aPressedOrOpenControlKeepsItsLabelReadable() {
        for appearance in Appearance.allCases {
            for surface in surfaces {
                let base = rgb(surface.color, in: appearance)
                let fill = rgb(Palette.overlayFill, in: appearance, over: base)
                #expect(ColorContrast.ratio(rgb(Palette.ink, in: appearance, over: fill), fill) >= ColorContrast.textMinimum, "\(surface.name), \(appearance)")
            }
            // The chosen text size in the script editor.
            #expect(ratio(Palette.ink, on: Palette.surface3, in: appearance) >= ColorContrast.textMinimum, "the picked size, \(appearance)")
        }
    }

    /// The meters (length, free exports): their fills are what the eye reads, so they need 3:1 on their track.
    @Test func meterFillsStandOutFromTheirTrack() {
        for appearance in Appearance.allCases {
            for surface in surfaces {
                let base = rgb(surface.color, in: appearance)
                let track = rgb(Palette.fill, in: appearance, over: base)
                for fill in [Palette.accText, Palette.warnText] {
                    let value = ColorContrast.ratio(rgb(fill, in: appearance, over: track), track)
                    #expect(value >= ColorContrast.componentMinimum, "a meter on \(surface.name), \(appearance): \(value)")
                }
            }
        }
    }

    // MARK: - Increase Contrast

    @Test func increaseContrastIsStrongerNotWeaker() {
        for (normal, increased) in [(Appearance.light, Appearance.lightIncreased), (.dark, .darkIncreased)] {
            for token in textTokens + tertiaryToken {
                for surface in surfaces {
                    let before = ratio(token.color, on: surface.color, in: normal)
                    let after = ratio(token.color, on: surface.color, in: increased)
                    #expect(after >= before - 0.001, "\(token.name) on \(surface.name), \(normal) → \(increased): \(before) → \(after)")
                }
            }
        }
    }

    @Test func theSecondaryTextStepsUpWithIncreaseContrast() {
        for (normal, increased) in [(Appearance.light, Appearance.lightIncreased), (.dark, .darkIncreased)] {
            #expect(ratio(Palette.ink2, on: Palette.surface, in: increased) > ratio(Palette.ink2, on: Palette.surface, in: normal))
            #expect(ratio(Palette.ink3, on: Palette.surface, in: increased) > ratio(Palette.ink3, on: Palette.surface, in: normal))
        }
    }

    // MARK: - The editor (always dark)

    @Test func theEditorsHintsAndIconsReadOnTheirTracks() {
        let strip = rgb(Palette.laneStrip, in: .dark)
        let active = rgb(Palette.laneStripActive, in: .dark)
        for background in [strip, active] {
            let hint = rgb(Palette.laneHintInk, in: .dark, over: background)
            #expect(ColorContrast.ratio(hint, background) >= ColorContrast.textMinimum, "the hint on an empty track")
        }
        let black = ColorContrast.RGB(red: 0, green: 0, blue: 0)
        let icon = rgb(Palette.laneGutterInk, in: .dark, over: black)
        #expect(ColorContrast.ratio(icon, black) >= ColorContrast.componentMinimum, "a track's icon in the gutter")
    }

    /// v26 lanes: each track's ink on its own fill, over the strip it sits on.
    @Test func theLanesInksReadOnTheirFills() {
        let lanes: [(name: String, fill: Color, ink: Color)] = [
            ("Aa", Palette.laneText, Palette.laneTextInk), ("Aa selected", Palette.laneTextSelected, Palette.laneTextInk),
            ("captions", Palette.laneCaption, Palette.laneCaptionInk), ("music", Palette.laneMusic, Palette.laneMusicInk),
            ("voice-over", Palette.laneVoiceOver, Palette.laneVoiceOverInk), ("overlay", Palette.laneMedia, Palette.laneMediaInk),
        ]
        for strip in [Palette.laneStrip, Palette.laneStripActive] {
            let base = rgb(strip, in: .dark)
            for lane in lanes {
                let fill = rgb(lane.fill, in: .dark, over: base)
                let ink = rgb(lane.ink, in: .dark, over: fill)
                #expect(ColorContrast.ratio(ink, fill) >= ColorContrast.textMinimum, "\(lane.name) on its lane")
            }
        }
    }

    /// The platform's recommendation over the camera: violet gradient (90% over black), its lines in
    /// `aiTextStrong`, the title and the icon's glyph. The warning card is night, with `ink2` lines.
    @Test func theCardsOverTheCameraReadOnTheirOwnFills() {
        let black = ColorContrast.RGB(red: 0, green: 0, blue: 0)
        for fill in [Palette.recommendationTop, Palette.recommendationBottom] {
            let card = rgb(fill, in: .dark, over: black)
            #expect(ColorContrast.ratio(rgb(Palette.aiTextStrong, in: .dark, over: card), card) >= ColorContrast.textMinimum, "a line on the recommendation")
            #expect(ColorContrast.ratio(rgb(Palette.ink, in: .dark, over: card), card) >= ColorContrast.textMinimum, "the title on the recommendation")
            let disc = rgb(Palette.recommendationIconFill, in: .dark, over: card)
            #expect(ColorContrast.ratio(rgb(Palette.recommendationIcon, in: .dark, over: disc), disc) >= ColorContrast.componentMinimum, "the icon")
        }
        let warning = rgb(Palette.warningCard, in: .dark, over: black)
        for token in [Palette.ink, Palette.ink2, Palette.warnText] {
            #expect(ColorContrast.ratio(rgb(token, in: .dark, over: warning), warning) >= ColorContrast.textMinimum, "the warning card")
        }
    }

    /// The toolbar's HUD and chips sit on the solid night glass (88%) over a bright camera feed.
    @Test func theToolbarsTextReadsOnSolidNightGlassOverAnyFeed() {
        for feed in [ColorContrast.RGB(red: 0, green: 0, blue: 0), ColorContrast.RGB(red: 1, green: 1, blue: 1)] {
            let glass = ColorContrast.composite(ColorContrast.RGB(hex: 0x0E101C), alpha: 0.88, over: feed)
            for token in [Palette.ink, Palette.ink2, Palette.accText] {
                let text = rgb(token, in: .dark, over: glass)
                #expect(ColorContrast.ratio(text, glass) >= ColorContrast.textMinimum, "text on solid glass")
            }
        }
    }

    // MARK: - The math

    @Test func theRatioIsTheStandardOne() {
        let black = ColorContrast.RGB(red: 0, green: 0, blue: 0)
        let white = ColorContrast.RGB(red: 1, green: 1, blue: 1)
        #expect(abs(ColorContrast.ratio(black, white) - 21) < 0.001)
        #expect(abs(ColorContrast.ratio(white, white) - 1) < 0.001)
        // #767676 on white is the classic 4.54:1.
        let gray = ColorContrast.RGB(hex: 0x767676)
        #expect(abs(ColorContrast.ratio(gray, white) - 4.54) < 0.01)
        // Translucent white over black is the gray it looks like.
        let half = ColorContrast.composite(white, alpha: 0.5, over: black)
        #expect(abs(half.red - 0.5) < 0.001)
    }
}
