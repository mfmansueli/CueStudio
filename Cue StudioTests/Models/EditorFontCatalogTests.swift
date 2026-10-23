//
//  EditorFontCatalogTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// One list of families for texts, captions and the cover: every one bundled and drawn in its own face, the cover's old
/// four still opening in the same faces, and a family picked over a caption preset drawn in that family.
@MainActor
@Suite("Editor font catalog")
struct EditorFontCatalogTests {
    /// The face's own name, as registered: what a family must resolve to (not the system's stand-in).
    private static let registered: [TextOverlayFont: String] = [
        .montserrat: "Montserrat", .tiktokSans: "TikTokSans", .poppins: "Poppins", .rubik: "Rubik", .dmSans: "DMSans",
        .spaceGrotesk: "SpaceGrotesk", .unbounded: "Unbounded", .syne: "Syne", .anton: "Anton", .bangers: "Bangers",
        .dmSerif: "DMSerifDisplay", .instrumentSerif: "InstrumentSerif", .caveat: "Caveat", .spaceMono: "SpaceMono",
    ]

    @Test func everyFamilyIsBundledAtEveryWeightItOffers() {
        #expect(Set(TextOverlayFont.editorFonts).count == TextOverlayFont.editorFonts.count)
        for face in TextOverlayFont.editorFonts where face != .sfPro {
            for weight in face.weights {
                let font = TextFont.font(face, weight: weight, size: 30, text: "Ação Größe ğış")
                #expect(font.fontName.contains(Self.registered[face] ?? "missing"), "\(face) \(weight): \(font.fontName)")
            }
        }
    }

    @Test func poppinsTakesTheFileOfEachWeight() {
        #expect(TextFont.font(.poppins, weight: .regular, size: 20, text: "A").fontName == "Poppins-Regular")
        #expect(TextFont.font(.poppins, weight: .medium, size: 20, text: "A").fontName == "Poppins-Medium")
        #expect(TextFont.font(.poppins, weight: .bold, size: 20, text: "A").fontName == "Poppins-Bold")
        #expect(TextFont.font(.poppins, weight: .heavy, size: 20, text: "A").fontName == "Poppins-ExtraBold")
    }

    @Test func aScriptTheFamilyLacksFallsBackToTheSystem() {
        let arabic = TextFont.font(.montserrat, weight: .bold, size: 30, text: "مرحبا")
        #expect(!arabic.fontName.contains("Montserrat"))
    }

    @Test func theNearestWeightLeansHeavier() {
        #expect(TextOverlayWeight.nearest(to: 800, in: TextOverlayWeight.editorWeights) == .heavy)
        #expect(TextOverlayWeight.nearest(to: 600, in: TextOverlayWeight.editorWeights) == .bold)
        #expect(TextOverlayWeight.nearest(to: 900, in: [.regular]) == .regular)
    }

    @Test func aCoverSavedWithItsOwnFourFacesOpensInTheSameOnes() throws {
        let decoder = JSONDecoder()
        let legacy: [(String, CoverFont)] = [
            ("anton", CoverFont(.anton)),
            ("grotesk", CoverFont(.spaceGrotesk, weight: .bold)),
            ("serif", CoverFont(.dmSerif)),
            ("system", CoverFont(.sfPro, weight: .heavy)),
        ]
        for (name, expected) in legacy {
            #expect(try decoder.decode(CoverFont.self, from: Data("\"\(name)\"".utf8)) == expected, "\(name)")
        }
        let picked = CoverFont(.montserrat, weight: .heavy)
        #expect(try decoder.decode(CoverFont.self, from: JSONEncoder().encode(picked)) == picked)
        // A weight the family doesn't have becomes its heaviest.
        #expect(CoverFont(.anton, weight: .bold).weight == .regular)
        #expect(CoverFont(.rubik).weight == .heavy)
    }

    @Test func aFamilyPickedOverAPresetDrawsTheLinesInItAndKeepsTheRest() {
        var settings = CaptionSettings(theme: .impact)
        let preset = settings.spec
        settings.face = .montserrat
        let font = CaptionFont.font(spec: settings.spec, size: 26, text: "Real talk")
        #expect(font.fontName.contains("Montserrat"))
        #expect(settings.spec.uppercase == preset.uppercase && settings.spec.outline == preset.outline)
        settings.face = nil
        #expect(CaptionFont.font(spec: settings.spec, size: 26, text: "Real talk").fontName.contains("Anton"))
    }
}
