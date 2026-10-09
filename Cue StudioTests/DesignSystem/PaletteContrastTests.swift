//
//  PaletteContrastTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

/// The palette against Apple's contrast guidelines (4.5:1 for text, 3:1 for the parts of a control),
/// with and without Increase Contrast. Cue is dark only (v27), so every pair is measured on the night.
@MainActor
@Suite("Palette contrast")
struct PaletteContrastTests {
    private enum Appearance: CaseIterable, CustomStringConvertible {
        case dark, darkIncreased

        var traits: UITraitCollection {
            let contrast: UIAccessibilityContrast = self == .darkIncreased ? .high : .normal
            return UITraitCollection(userInterfaceStyle: .dark).modifyingTraits { traits in
                traits.accessibilityContrast = contrast
            }
        }

        var description: String { self == .dark ? "dark" : "dark + Increase Contrast" }
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
        ("ink", Palette.ink), ("ink2", Palette.ink2), ("inkHint", Palette.inkHint), ("accText", Palette.accText), ("warnText", Palette.warnText),
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

    /// Where the hint text sits in the app: the sheets and the soft control fill are lighter than the page.
    /// (Not the tile surface: `inkHint` is 4.3:1 there, so tiles use `ink2`.)
    @Test func hintInkReadsOnTheLighterFillsItSitsOn() {
        let fills: [(name: String, color: Color)] = [
            ("sheetNight", Palette.sheetNight), ("fill", Palette.fill),
        ]
        for appearance in Appearance.allCases {
            for fill in fills {
                let value = ratio(Palette.inkHint, on: fill.color, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "inkHint on \(fill.name), \(appearance): \(value)")
            }
        }
    }

    /// The reminder sheet and a tool's introduction (`ReminderSheet`, `FeatureIntroSheet`): their words on the sheet's night, the "past" warning
    /// included, and the tool's icon (3:1, it informs) on its tile.
    @Test func theNotificationSheetsReadOnTheirNight() {
        for appearance in Appearance.allCases {
            for (name, token) in [("ink", Palette.ink), ("ink2", Palette.ink2), ("warnText", Palette.warnText)] {
                let value = ratio(token, on: Palette.sheetNight, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "\(name) on sheetNight, \(appearance): \(value)")
            }
            #expect(ratio(Palette.aiText, on: Palette.surface2, in: appearance) >= 3, "the tool's icon, \(appearance)")
            #expect(ratio(Palette.accInk, on: Palette.acc, in: appearance) >= ColorContrast.textMinimum, "a routine day picked, \(appearance)")
            #expect(ratio(Palette.ink, on: Palette.surface3, in: appearance) >= ColorContrast.textMinimum, "a routine day not picked, \(appearance)")
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
            #expect(ratio(Palette.inkOnLight, on: .white, in: appearance) >= ColorContrast.textMinimum, "inkOnLight on a white chip, \(appearance)")
            #expect(ratio(Palette.bg, on: Palette.ink, in: appearance) >= ColorContrast.textMinimum, "a selected chip, \(appearance)")
            #expect(ratio(.white, on: Palette.neutralAction, in: appearance) >= ColorContrast.textMinimum, "white on neutralAction, \(appearance)")
            #expect(ratio(.white, on: Palette.Takes.shareAction, in: appearance) >= ColorContrast.textMinimum, "white on the Share action, \(appearance)")
            // v26 controls: the selected chip and the selected segment, with the text they carry.
            #expect(ratio(Palette.chipOnInk, on: Palette.chipOn, in: appearance) >= ColorContrast.textMinimum, "the selected chip, \(appearance)")
            #expect(ratio(Palette.ink, on: Palette.segmentOn, in: appearance) >= ColorContrast.textMinimum, "the selected segment, \(appearance)")
            #expect(ratio(Palette.ink, on: Palette.fill, in: appearance) >= ColorContrast.textMinimum, "an unselected chip, \(appearance)")
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

    // MARK: - Cards

    /// The prompt box: the title sits where the golden light is brightest (34%), the caption and the
    /// description where it is dimmer (13%), and the field is sunk into it..
    @Test func thePromptBoxReadsOverItsGoldenWash() {
        for appearance in Appearance.allCases {
            for base in [Palette.surface, Palette.surface2] {
                let card = rgb(base, in: appearance)
                let bright = rgb(Palette.acc.opacity(0.34), in: appearance, over: card)
                let dim = rgb(Palette.acc.opacity(0.13), in: appearance, over: card)
                #expect(ColorContrast.ratio(rgb(Palette.ink, in: appearance, over: bright), bright) >= ColorContrast.textMinimum, "the title, \(appearance)")
                let field = rgb(Palette.insetField, in: appearance, over: dim)
                for token in [Palette.ink, Palette.ink2] {
                    let text = rgb(token, in: appearance, over: field)
                    #expect(ColorContrast.ratio(text, field) >= ColorContrast.textMinimum, "text in the field, \(appearance)")
                }
            }
        }
    }

    /// The panels under Quick edit's timeline.
    @Test func theEditorsPanelReads() {
        for appearance in Appearance.allCases {
            for token in textTokens {
                let value = ratio(token.color, on: Palette.Editor.panel, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "\(token.name) on the panel, \(appearance): \(value)")
            }
            #expect(
                ratio(Palette.Editor.laneGhostBorder, on: Palette.Editor.panel, in: appearance) >= ColorContrast.componentMinimum,
                "a dashed outline, \(appearance)"
            )
            // Text style and Caption style: the expand button's arrows, and the scope's and the
            // captions action's label on their gray (ink on `fill`, over the panel); an unpicked
            // segment is ink2 on the same gray.
            for token in [("ink", Palette.ink), ("ink2", Palette.ink2)] {
                let onFill = ratio(token.1, onTint: Palette.fill, over: Palette.Editor.panel, in: appearance)
                #expect(onFill >= ColorContrast.textMinimum, "\(token.0) on fill over the panel, \(appearance): \(onFill)")
            }
        }
    }

    @Test func settingsSheetsOverTheCameraRead() {
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
            // A picked tile.
            #expect(ratio(Palette.ink, on: Palette.surface3, in: appearance) >= ColorContrast.textMinimum, "a picked tile, \(appearance)")
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
        for (normal, increased) in [(Appearance.dark, Appearance.darkIncreased)] {
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
        for (normal, increased) in [(Appearance.dark, Appearance.darkIncreased)] {
            #expect(ratio(Palette.ink2, on: Palette.surface, in: increased) > ratio(Palette.ink2, on: Palette.surface, in: normal))
            #expect(ratio(Palette.ink3, on: Palette.surface, in: increased) > ratio(Palette.ink3, on: Palette.surface, in: normal))
        }
    }

    // MARK: - The editor (always dark)

    @Test func theEditorsHintsAndIconsReadOnTheirTracks() {
        let strip = rgb(Palette.Editor.laneStrip, in: .dark)
        let active = rgb(Palette.Editor.laneStripActive, in: .dark)
        for background in [strip, active] {
            let hint = rgb(Palette.Editor.laneHintInk, in: .dark, over: background)
            #expect(ColorContrast.ratio(hint, background) >= ColorContrast.textMinimum, "the hint on an empty track")
        }
        let black = ColorContrast.RGB(red: 0, green: 0, blue: 0)
        let icon = rgb(Palette.Editor.laneGutterInk, in: .dark, over: black)
        #expect(ColorContrast.ratio(icon, black) >= ColorContrast.componentMinimum, "a track's icon in the gutter")
    }

    /// v26 lanes: each track's ink on its own fill, over the strip it sits on.
    @Test func theLanesInksReadOnTheirFills() {
        let lanes: [(name: String, fill: Color, ink: Color)] = [
            ("Aa", Palette.Editor.laneText, Palette.Editor.laneTextInk), ("Aa selected", Palette.Editor.laneTextSelected, Palette.Editor.laneTextInk),
            ("captions", Palette.Editor.laneCaption, Palette.Editor.laneCaptionInk), ("music", Palette.Editor.laneMusic, Palette.Editor.laneMusicInk),
            ("voice-over", Palette.Editor.laneVoiceOver, Palette.Editor.laneVoiceOverInk), ("overlay", Palette.Editor.laneMedia, Palette.Editor.laneMediaInk),
        ]
        for strip in [Palette.Editor.laneStrip, Palette.Editor.laneStripActive] {
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
        for fill in [Palette.Camera.recommendationTop, Palette.Camera.recommendationBottom] {
            let card = rgb(fill, in: .dark, over: black)
            #expect(ColorContrast.ratio(rgb(Palette.aiTextStrong, in: .dark, over: card), card) >= ColorContrast.textMinimum, "a line on the recommendation")
            #expect(ColorContrast.ratio(rgb(Palette.ink, in: .dark, over: card), card) >= ColorContrast.textMinimum, "the title on the recommendation")
            let disc = rgb(Palette.Camera.recommendationIconFill, in: .dark, over: card)
            #expect(ColorContrast.ratio(rgb(Palette.Camera.recommendationIcon, in: .dark, over: disc), disc) >= ColorContrast.componentMinimum, "the icon")
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

    /// The star's words over its cover (84% of `transitionCover`, 09 §8) on whatever the screen behind it shows: black, and at worst white.
    @Test func theStarsWordsReadOverItsCoverOnAnyScreen() {
        let words: [(name: String, color: Color)] = [
            ("the title", Palette.ink), ("the idea and Cancel", Palette.Scripts.transitionInk), ("the phrase", Palette.Scripts.transitionPhrase),
            ("the percentage", Palette.ink2),
        ]
        for screen in [ColorContrast.RGB(red: 0, green: 0, blue: 0), ColorContrast.RGB(red: 1, green: 1, blue: 1)] {
            for appearance in Appearance.allCases {
                let cover = ColorContrast.composite(rgb(Palette.Scripts.transitionCover, in: appearance), alpha: 0.84, over: screen)
                for word in words {
                    let measured = ColorContrast.ratio(rgb(word.color, in: appearance, over: cover), cover)
                    #expect(measured >= ColorContrast.textMinimum, "\(word.name), \(appearance): \(measured)")
                }
            }
        }
    }

    /// "✦ Writing in your voice 42%": the page's pill, its words on the violet fill over the page.
    @Test func theWritingPillReadsOnItsFill() {
        for appearance in Appearance.allCases {
            let measured = ratio(Palette.aiTextStrong, onTint: Palette.Page.writingPillFill, over: Palette.bg, in: appearance)
            #expect(measured >= ColorContrast.textMinimum, "\(appearance): \(measured)")
        }
    }

    // MARK: - v29

    /// Colored text inside a chip: the ink on the chip's fill, over each surface it can sit on.
    @Test func theStateChipsReadOnTheirFillsOverEverySurface() {
        let chips: [(name: String, ink: Color, fill: Color)] = [
            ("READY", Palette.Page.stateReadyInk, Palette.Page.stateReadyFill), ("DRAFT", Palette.Page.stateDraftInk, Palette.Page.stateDraftFill),
            ("RECORDED", Palette.Page.stateRecordedInk, Palette.Page.stateRecordedFill),
        ]
        for appearance in Appearance.allCases {
            for chip in chips {
                for surface in surfaces {
                    let value = ratio(chip.ink, onTint: chip.fill, over: surface.color, in: appearance)
                    #expect(value >= ColorContrast.textMinimum, "\(chip.name) on \(surface.name), \(appearance): \(value)")
                }
            }
            #expect(ratio(Palette.Scripts.adTagInk, on: Palette.Scripts.adTagFill, in: appearance) >= ColorContrast.textMinimum, "the #AD tag, \(appearance)")
        }
    }

    @Test func textRewrittenByTheAIReadsBeforeItIsKept() {
        for appearance in Appearance.allCases {
            for surface in surfaces {
                let value = ratio(Palette.Page.aiReplacedInk, onTint: Palette.Page.aiReplacedFill, over: surface.color, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "pending AI text on \(surface.name), \(appearance): \(value)")
            }
        }
    }

    /// The AI bar over a selection (a night violet at 97%, over the page or a card) and the state strip (night at
    /// 92%): their labels read over any surface behind them.
    @Test func theSelectionBarAndTheStateStripReadOverTheScreen() {
        let bars: [(name: String, fill: Color, text: [Color])] = [
            ("selection bar", Palette.Page.selectionBar, [Palette.ink, Palette.aiText, Palette.aiTextStrong]),
            ("state strip", Palette.Page.stripFill, [Palette.ink, Palette.ink2, Palette.accText, Palette.successText, Palette.aiText]),
        ]
        for appearance in Appearance.allCases {
            for bar in bars {
                for surface in surfaces {
                    for token in bar.text {
                        let value = ratio(token, onTint: bar.fill, over: surface.color, in: appearance)
                        #expect(value >= ColorContrast.textMinimum, "text on the \(bar.name) over \(surface.name), \(appearance): \(value)")
                    }
                }
            }
        }
    }

    /// The slider: the white thumb and the yellow fill stand out from the track and from every surface (3:1).
    @Test func theSliderPartsStandOutFromTheirSurface() {
        for appearance in Appearance.allCases {
            for surface in surfaces {
                let thumb = ratio(Palette.Slider.thumb, on: surface.color, in: appearance)
                #expect(thumb >= ColorContrast.componentMinimum, "thumb on \(surface.name)")
                let base = rgb(surface.color, in: appearance)
                let track = rgb(Palette.Slider.track, in: appearance, over: base)
                let fill = rgb(Palette.Slider.fill, in: appearance, over: track)
                #expect(ColorContrast.ratio(fill, track) >= ColorContrast.componentMinimum, "fill on the track over \(surface.name), \(appearance)")
                let thumbOnTrack = ColorContrast.ratio(rgb(Palette.Slider.thumb, in: appearance, over: track), track)
                #expect(thumbOnTrack >= ColorContrast.componentMinimum, "thumb on the track")
            }
        }
    }

    /// The "● REC" label, and the empty state's title and line, over the night.
    @Test func theRecPillAndTheEmptyStateRead() {
        for appearance in Appearance.allCases {
            for surface in surfaces {
                #expect(ratio(Palette.ink, on: surface.color, in: appearance) >= ColorContrast.textMinimum, "REC on \(surface.name)")
                #expect(ratio(Palette.ink2, on: surface.color, in: appearance) >= ColorContrast.textMinimum, "the empty state's line on \(surface.name)")
            }
            // The violet core of the ring sits behind the title at its strongest.
            let core = rgb(Palette.Scripts.emptyRingCore, in: appearance, over: rgb(Palette.bg, in: appearance))
            #expect(ColorContrast.ratio(rgb(Palette.ink, in: appearance, over: core), core) >= ColorContrast.textMinimum)
        }
    }

    // MARK: - The math

    /// Interstellar (Starry sky): the night under every browse screen is darker than `bg`, so every text token reads on it, and still reads at its
    /// brightest point: a wash light, a nebula's heart and the Milky Way band all on the same spot (the rule: the worst point, not the average).
    @Test func theInterstellarNightKeepsTheTextTokensReadableEvenAtItsBrightestPoint() {
        let washes: [(name: String, color: Color)] = [
            ("indigo", Palette.Sky.interstellarWashIndigo), ("magenta", Palette.Sky.interstellarWashMagenta), ("teal", Palette.Sky.interstellarWashTeal),
        ]
        let nebulae: [(name: String, hue: NebulaHue)] = [("blue", .blue), ("magenta", .magenta), ("teal", .teal)]
        let nebulaPeak = StarfieldMath.interstellarNebulaOpacity.upperBound
        let band = Palette.Sky.interstellarBand.opacity(StarfieldMath.bandPeakOpacity)
        let tokens: [(name: String, color: Color)] = [("ink", Palette.ink), ("ink2", Palette.ink2), ("inkHint", Palette.inkHint)]

        for appearance in Appearance.allCases {
            let base = rgb(Palette.Sky.interstellarBg, in: appearance)
            for token in textTokens {
                let value = ratio(token.color, on: Palette.Sky.interstellarBg, in: appearance)
                #expect(value >= ColorContrast.textMinimum, "\(token.name) on the interstellar night, \(appearance): \(value)")
            }
            for wash in washes {
                for nebula in nebulae {
                    let lit = rgb(wash.color, in: appearance, over: base)
                    let withNebula = rgb(nebula.hue.color.opacity(nebulaPeak), in: appearance, over: lit)
                    let brightest = rgb(band, in: appearance, over: withNebula)
                    for token in tokens {
                        let value = ColorContrast.ratio(rgb(token.color, in: appearance, over: brightest), brightest)
                        #expect(
                            value >= ColorContrast.textMinimum,
                            "\(token.name) on the \(wash.name) wash + \(nebula.name) nebula + band, \(appearance): \(value)"
                        )
                    }
                }
            }
        }
    }

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
