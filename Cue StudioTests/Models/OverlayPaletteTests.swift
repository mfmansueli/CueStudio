//
//  OverlayPaletteTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One palette for every color the editor and the cover offer, and the captions' highlights in it.
@Suite("Overlay palette")
struct OverlayPaletteTests {
    @Test func thePaletteIsTheCanvasThirteenInItsOrder() {
        #expect(OverlayColor.palette.map(\.rawValue) == [
            "white", "paper", "offBlack", "yellow", "peach", "orange", "red", "blush", "lavender", "blue", "cyan", "mint", "lime",
        ])
        // Ink, not pure black; one yellow.
        #expect(!OverlayColor.palette.contains(.black))
        #expect(OverlayColor.yellow.components == (1, 0.839, 0.039))
    }

    @Test func aHighlightSavedBeforeThePaletteReadsTheSame() throws {
        for name in ["yellow", "lime", "peach", "white"] {
            let decoded = try JSONDecoder().decode(CaptionAccent.self, from: Data("\"\(name)\"".utf8))
            #expect(decoded.rawValue == name)
            #expect(OverlayColor.palette.contains(decoded))
        }
    }

    @Test func aHighlightThatWouldVanishFallsBackToOneThatStandsOut() {
        var look = TypePreset.cue.look(for: .caption)
        look.color = .yellow
        #expect(!CaptionAccent.yellow.standsOut(on: look))
        #expect(CaptionAccent.yellow.standingOut(on: look) == .white)
    }
}
