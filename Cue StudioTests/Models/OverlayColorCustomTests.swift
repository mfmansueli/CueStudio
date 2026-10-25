//
//  OverlayColorCustomTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A creator's own color (a brand's exact one): kept as "#RRGGBB", drawn as it is, read back as it was; a named color stays
/// named, even when picked by its numbers; edits saved before read the same; a value Cue doesn't know reads as white.
@Suite("Colors of the creator's own")
struct OverlayColorCustomTests {
    @Test func aCustomColorIsKeptAsItsHexAndDrawnAsItIs() throws {
        let blue = OverlayColor.custom(red: 0.118, green: 0.4, blue: 0.961)
        #expect(blue.rawValue == "#1E66F5")
        #expect(blue.isCustom)
        #expect(abs(blue.components.blue - 245.0 / 255) < 0.001)
        #expect(blue.label == "Color #1E66F5")
        #expect(OverlayColor(rawValue: "#1e66f5") == blue)
        let data = try JSONEncoder().encode([blue, .yellow])
        #expect(String(bytes: data, encoding: .utf8) == "[\"#1E66F5\",\"yellow\"]")
        #expect(try JSONDecoder().decode([OverlayColor].self, from: data) == [blue, .yellow])
    }

    @Test func aNamedColorStaysNamedAndOldEditsReadTheSame() throws {
        let yellow = OverlayColor.yellow.components
        #expect(OverlayColor.custom(red: yellow.red, green: yellow.green, blue: yellow.blue) == .yellow)
        #expect(!OverlayColor.yellow.isCustom)
        #expect(OverlayColor.allCases.count == 17)
        #expect(OverlayColor.palette.count == 13)
        #expect(try JSONDecoder().decode([OverlayColor].self, from: Data("[\"offBlack\",\"lime\"]".utf8)) == [.offBlack, .lime])
        // A value this version doesn't know: white, as before.
        #expect(try JSONDecoder().decode([OverlayColor].self, from: Data("[\"neon\",\"#12\"]".utf8)) == [.white, .white])
    }
}
