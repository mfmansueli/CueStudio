//
//  CaptionCatalogTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The catalogue of twenty: whole recipes, never a color away from one another, each readable without motion, in a bundled
/// face, and the seven older styles still reading as they did for the edits saved with them.
@MainActor
@Suite("Caption catalogue")
struct CaptionCatalogTests {
    private struct Traits: Equatable {
        let family: String
        let letterCase: CaptionLetterCase
        let background: CaptionBackground
        let spoken: CaptionSpokenHighlight
        let reveal: CaptionReveal
        let entry: CaptionEntry
    }

    private func traits(_ theme: CaptionTheme) -> Traits {
        let spec = CaptionSettings(theme: theme).spec
        let motion = spec.motion ?? CaptionMotion()
        return Traits(
            family: spec.face?.rawValue ?? spec.fontName.components(separatedBy: "-")[0], letterCase: spec.letterCase,
            background: CaptionBackground(spec.plate), spoken: motion.spoken, reveal: motion.reveal, entry: motion.entry
        )
    }

    @Test func everyTwoStylesDifferInAtLeastTwoWaysBesidesColor() {
        let themes = CaptionTheme.catalog
        for (index, first) in themes.enumerated() {
            for second in themes[(index + 1)...] {
                let a = traits(first), b = traits(second)
                let differences = [
                    a.family != b.family, a.letterCase != b.letterCase, a.background != b.background,
                    a.spoken != b.spoken || a.reveal != b.reveal, a.entry != b.entry,
                ].filter { $0 }.count
                #expect(differences >= 2, "\(first) and \(second) differ in \(differences) way")
            }
        }
    }

    @Test(arguments: CaptionTheme.catalog)
    func everyStyleIsAWholeRecipeInABundledFace(_ theme: CaptionTheme) throws {
        let settings = CaptionSettings(theme: theme)
        let spec = settings.spec
        #expect(settings.styleVersion == 3 && settings.motion == spec.motion && spec.motion != nil)
        #expect(settings.followsWords == spec.motion?.followsWords)
        #expect((19...32).contains(spec.baseSize))
        #expect((0.6...0.9).contains(spec.widthFraction))
        #expect((1...1.3).contains(spec.emphasisScale))
        let font = CaptionFont.font(spec: spec, size: 24, text: "Make it real")
        #expect(!font.fontName.hasPrefix("."), "\(theme) draws in the system's stand-in")
        // Readable with no motion at all: the still caption draws, and something is behind its letters.
        let image = try #require(CaptionCollectionRenderer.image("Make it real today", settings: settings, frame: CGSize(width: 1080, height: 1920)))
        #expect(image.size.width > 0)
        let behind = spec.plate != .none || (spec.outline?.width ?? 0) >= 5 || (spec.shadow?.passes ?? 1) > 1
        #expect(behind, "\(theme) has only a light shadow behind its words")
        #expect(!theme.summary.isEmpty && theme.label != theme.rawValue || theme == .cue)
    }

    @Test func theSevenOlderStylesKeepTheirEarlierReadings() {
        for theme in CaptionTheme.allCases {
            #expect(theme.existedBeforeCatalog == [.cue, .impact, .clean, .pop, .editorial, .educational, .interview].contains(theme))
        }
        // An edit saved with the complete presets keeps them; a new one gets the catalogue's.
        #expect(CaptionStyleSpec.spec(for: .pop, version: 2) != CaptionStyleSpec.spec(for: .pop, version: 3))
        #expect(CaptionStyleSpec.spec(for: .pop, version: 2).motion == nil)
        // A style that didn't exist before has only the catalogue's reading.
        #expect(CaptionStyleSpec.spec(for: .comic, version: 1) == CaptionStyleSpec.spec(for: .comic, version: 3))
    }

    @Test func aCaptionSavedWithAStyleThisVersionDoesntKnowReadsAsCue() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(CaptionSettings(theme: .comic))) as? [String: Any])
        object["theme"] = "hologram"
        var motion = try #require(object["motion"] as? [String: Any])
        motion["spoken"] = "sparkle"
        object["motion"] = motion
        let settings = try JSONDecoder().decode(CaptionSettings.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(settings.theme == .cue)
        #expect(settings.motion?.spoken == .color)
        #expect(settings.motion?.entry == .pop)
    }
}
