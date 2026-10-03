//
//  LazyTextTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The compositor's cache names each drawing by everything it depends on: the preview keeps its
/// compositor across changes, so a corrected word or a new style must never come back from the
/// cache as it was.
@Suite("LazyText")
struct LazyTextTests {
    private func title(_ text: String) -> TextOverlay {
        var title = TextOverlay(role: .title, look: TypePreset.cue.look(for: .title), preset: .cue, span: TimeSpan(start: 0, end: 2))
        title.text = text
        return title
    }

    private func lazy(_ text: TextOverlay, emphasis: WordEmphasis? = nil, collection: CaptionSettings? = nil) -> LazyText {
        LazyText(text: text, emphasis: emphasis, frameWidth: 1080, widthFraction: 0.8, collection: collection)
    }

    @Test func theSameDrawingHasTheSameKey() {
        let text = title("5 comidas de SP")
        #expect(lazy(text).key == lazy(text).key)
    }

    @Test func newWordsAreANewDrawing() {
        var text = title("5 comidas de SP")
        let before = lazy(text).key
        text.text = "5 comidas de SP!"
        #expect(lazy(text).key != before)
    }

    @Test func aNewLookIsANewDrawing() {
        var text = title("5 comidas de SP")
        let before = lazy(text).key
        text.color = .yellow
        #expect(lazy(text).key != before)
    }

    @Test func eachWordAndEachCollectionStyleIsItsOwnDrawing() {
        let text = title("Massa fina")
        let words = ["Massa", "fina"]
        let first = lazy(text, emphasis: WordEmphasis(words: words, index: 0, style: .reveal))
        let second = lazy(text, emphasis: WordEmphasis(words: words, index: 1, style: .reveal))
        #expect(first.key != second.key)
        var settings = CaptionSettings()
        let plain = lazy(text, collection: settings)
        settings.theme = .pop
        #expect(lazy(text, collection: settings).key != plain.key)
    }
}
