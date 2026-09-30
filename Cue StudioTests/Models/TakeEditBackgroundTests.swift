//
//  TakeEditBackgroundTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Backgrounds in the recipe: one per recording, settings kept while Original, and their photos
/// kept with the edit's media.
@Suite("TakeEdit backgrounds")
struct TakeEditBackgroundTests {
    @Test func eachRecordingHasItsOwn() {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        let other = UUID()
        var blur = BackgroundEffect()
        blur.style = .blur
        var color = BackgroundEffect()
        color.style = .color
        edit.setBackground(blur, for: nil)
        edit.setBackground(color, for: other)
        #expect(edit.background(for: nil)?.style == .blur)
        #expect(edit.background(for: other)?.style == .color)
        #expect(edit.backgrounds.count == 2)
    }

    @Test func originalKeepsTheSettingsButChangesNothing() {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        var effect = BackgroundEffect()
        effect.cutout = .colorKey
        effect.key.tolerance = 0.7
        edit.setBackground(effect, for: nil)
        #expect(edit.background(for: nil) == nil)
        #expect(edit.backgrounds.first?.effect.key.tolerance == 0.7)
        // Nothing left to keep: the entry goes.
        edit.setBackground(BackgroundEffect(), for: nil)
        #expect(edit.backgrounds.isEmpty)
    }

    @Test func thePhotoIsPartOfTheEditsMediaAndComesBack() throws {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        var effect = BackgroundEffect()
        effect.style = .image
        effect.imageFileName = "beach.jpg"
        edit.setBackground(effect, for: nil)
        #expect(edit.mediaFileNames.contains("beach.jpg"))
        let decoded = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(edit))
        #expect(decoded.background(for: nil) == effect)
    }
}
