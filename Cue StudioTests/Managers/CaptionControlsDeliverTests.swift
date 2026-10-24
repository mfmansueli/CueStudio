//
//  CaptionControlsDeliverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Every choice in Caption style changes what is drawn: each option is drawn with the export's renderer and compared with the
/// caption before it, so no control is there without an effect (a family with weights that all look alike, a background
/// opacity on no background, an alignment a one-line caption doesn't show).
@MainActor
@Suite("Caption controls deliver")
struct CaptionControlsDeliverTests {
    private let frame = CGSize(width: 1080, height: 1920)
    private let text = "Make it real one take at a time"

    private func drawn(_ settings: CaptionSettings, markup: CaptionMarkup? = nil) -> Data? {
        CaptionCollectionRenderer.image(text, settings: settings, frame: frame, markup: markup)?.pngData()
    }

    private func adjusted(_ theme: CaptionTheme = .educational, _ change: (inout CaptionAdjustments) -> Void) -> CaptionSettings {
        var settings = CaptionSettings(theme: theme)
        var adjustments = CaptionAdjustments()
        change(&adjustments)
        settings.adjustments = adjustments
        return settings
    }

    @Test func everyFamilyAndEachOfItsWeightsDrawDifferently() throws {
        let base = drawn(CaptionSettings(theme: .educational))
        for face in TextOverlayFont.editorFonts {
            var settings = CaptionSettings(theme: .educational)
            settings.face = face
            #expect(drawn(settings) != base, "\(face) draws as the style's own font")
            let weights = settings.availableWeights
            guard weights.count > 1, let lightest = weights.first, let heaviest = weights.last else { continue }
            var light = settings, heavy = settings
            light.adjustments = CaptionAdjustments()
            light.adjustments?.weight = lightest
            heavy.adjustments = CaptionAdjustments()
            heavy.adjustments?.weight = heaviest
            #expect(drawn(light) != drawn(heavy), "\(face): \(lightest) and \(heaviest) look the same")
        }
    }

    @Test func caseColorBackgroundOutlineShadowAndSpacingEachChangeTheCaption() {
        let base = drawn(CaptionSettings(theme: .educational))
        let changes: [(String, (inout CaptionAdjustments) -> Void)] = [
            ("capitals", { $0.letterCase = .upper }), ("small letters", { $0.letterCase = .lower }),
            ("text color", { $0.textColor = .peach }), ("background color", { $0.backgroundColor = .blue }),
            ("background opacity", { $0.backgroundOpacity = 0.3 }), ("thin outline", { $0.outline = .thin }),
            ("thick outline", { $0.outline = .thick }), ("soft shadow", { $0.shadow = .soft }), ("halo", { $0.shadow = .halo }),
            ("glow", { $0.shadow = .glow }), ("letter spacing", { $0.tracking = 2 }),
        ]
        for (name, change) in changes {
            #expect(drawn(adjusted(.educational, change)) != base, "\(name) changes nothing")
        }
        // Each background differs from the others.
        let backgrounds = CaptionBackground.allCases.map { kind in drawn(adjusted { $0.background = kind }) }
        #expect(Set(backgrounds.compactMap { $0 }).count == CaptionBackground.allCases.count)
        // An outline's color shows once there is an outline.
        #expect(drawn(adjusted(.outline) { $0.outlineColor = .red }) != drawn(CaptionSettings(theme: .outline)))
    }

    @Test func theWordSaidAndTheMarkedWordsShowInEveryWay() {
        let settings = CaptionSettings(theme: .educational)
        let plain = drawn(settings, markup: CaptionMarkup())
        var images: [Data?] = []
        for spoken in CaptionSpokenHighlight.allCases where spoken != .none {
            var markup = CaptionMarkup(lit: 2, spoken: spoken)
            if spoken == .pop { markup.popScale = CaptionSpokenHighlight.popScale }
            images.append(drawn(settings, markup: markup))
        }
        #expect(images.allSatisfy { $0 != plain })
        #expect(Set(images.compactMap { $0 }).count >= 3, "color, box and pop should each look their own")
        var colored = settings
        colored.accent = .lime
        let lit = CaptionMarkup(lit: 2, spoken: .color)
        #expect(drawn(colored, markup: lit) != drawn(settings, markup: lit))
        let marked = drawn(settings, markup: CaptionMarkup(emphasized: [2]))
        #expect(marked != plain, "a marked word looks like the others")
        #expect(drawn(adjusted { $0.emphasisColor = .blue }, markup: CaptionMarkup(emphasized: [2])) != marked)
        #expect(drawn(adjusted { $0.emphasisSize = .biggest }, markup: CaptionMarkup(emphasized: [2])) != marked)
    }

    @Test func sizeWidthAndAlignmentMoveOrResizeTheCaption() throws {
        let cue = CaptionCue(text: "Make it real", start: 0, end: 2, origin: .manual)
        func placed(_ settings: CaptionSettings) -> CGRect? {
            let first = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame).first
            return first.map { CGRect(origin: $0.origin, size: $0.size) }
        }
        let base = try #require(placed(CaptionSettings(theme: .educational)))
        var bigger = CaptionSettings(theme: .educational)
        bigger.sizeScale = 1.4
        #expect(try #require(placed(bigger)).width > base.width)
        var left = CaptionSettings(theme: .educational)
        left.alignment = .leading
        var right = left
        right.alignment = .trailing
        let leftRect = try #require(placed(left)), rightRect = try #require(placed(right))
        #expect(leftRect.minX < base.minX && rightRect.maxX > base.maxX, "a one-line caption doesn't move with its alignment")
        var narrow = CaptionSettings(theme: .educational)
        narrow.width = .narrow
        var wide = narrow
        wide.width = .wide
        let long = "Make it real one take at a time and keep going"
        #expect(CaptionCollectionRenderer.measure(long, settings: narrow, frame: frame)?.lines
            != CaptionCollectionRenderer.measure(long, settings: wide, frame: frame)?.lines)
    }

    @Test func eachWayInIsPlayed() {
        let cue = CaptionCue(text: "Make it real", start: 0, end: 2, origin: .manual)
        for entry in CaptionEntry.allCases {
            var settings = CaptionSettings(theme: .clean)
            settings.motion?.entry = entry
            let first = CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame).first
            switch entry {
            case .none: #expect(first?.fadeIn == 0 && first?.popDuration == 0 && first?.riseDuration == 0)
            case .fade: #expect((first?.fadeIn ?? 0) > 0)
            case .pop: #expect((first?.popDuration ?? 0) > 0 && (first?.popScale ?? 1) < 1)
            case .rise: #expect((first?.riseDuration ?? 0) > 0 && (first?.riseDistance ?? 0) > 0)
            }
        }
    }
}
