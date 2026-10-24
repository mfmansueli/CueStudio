//
//  CaptionCatalogContrastTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Every style of the catalogue reads on the brightest and the darkest picture, measured on the drawn pixels
/// (`CaptionContrastProbe`): the words 4.5:1 against what is right around their letters, the word being said and a word marked
/// for emphasis 3:1 (captions are large text).
@MainActor
@Suite("Caption catalogue contrast")
struct CaptionCatalogContrastTests {
    private static let scenes: [(name: String, color: ColorContrast.RGB)] = [
        ("white", ColorContrast.RGB(red: 1, green: 1, blue: 1)), ("black", ColorContrast.RGB(red: 0, green: 0, blue: 0)),
        ("gray", ColorContrast.RGB(red: 0.5, green: 0.5, blue: 0.5)),
    ]

    @Test(arguments: CaptionTheme.catalog)
    func theWordsReadOnAnyPicture(_ theme: CaptionTheme) throws {
        let settings = CaptionSettings(theme: theme)
        for scene in Self.scenes {
            let reading = try #require(CaptionContrastProbe.reading(settings, over: scene.color))
            print("contrast \(theme.rawValue) \(scene.name) words \(String(format: "%.2f", reading.words)) said \(String(format: "%.2f", reading.lit)) marked \(String(format: "%.2f", reading.emphasis))")
            #expect(reading.words >= ColorContrast.textMinimum, "\(theme) words on \(scene.name): \(reading.words)")
            if settings.motion?.spoken != CaptionSpokenHighlight.none {
                #expect(reading.lit >= ColorContrast.largeTextMinimum, "\(theme) word said on \(scene.name): \(reading.lit)")
            }
            #expect(reading.emphasis >= ColorContrast.largeTextMinimum, "\(theme) emphasis on \(scene.name): \(reading.emphasis)")
        }
    }
}
