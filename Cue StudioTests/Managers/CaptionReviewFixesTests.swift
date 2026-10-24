//
//  CaptionReviewFixesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// What the independent review of Phase 3 found, as the behaviour it should have: a copied look with motion still lights the
/// word said, video templates keep their reveal, marks follow their words through a cut, a line's way in runs across its states,
/// one card is marked, and saved styles a newer version wrote are never replaced.
@MainActor
@Suite("Caption review fixes")
struct CaptionReviewFixesTests {
    private let frame = CGSize(width: 1080, height: 1920)

    private func timed(_ text: String, from start: TimeInterval = 0.2) -> CaptionCue {
        CaptionCue(words: CaptionText.words(in: text).enumerated().map { index, word in
            CaptionWord(text: word, start: start + Double(index) * 0.4, end: start + Double(index) * 0.4 + 0.34)
        })
    }

    @Test func aCopiedLookWithMotionStillLightsTheWordSaid() throws {
        var settings = CaptionSettings(theme: .cue)
        settings.customLook = TypePreset.label.look(for: .caption)
        let states = CaptionCollectionRenderer.overlays([timed("Make it real today")], settings: settings, position: .bottom, frame: frame)
        #expect(states.contains { $0.lazyText?.markup?.lit != nil })
        #expect(states.allSatisfy { $0.lazyText?.collection?.customLook == nil }, "drawn by the collection, which knows the markup")
    }

    @Test(arguments: VideoTemplate.allCases)
    func aVideoTemplateKeepsItsWayOfShowingWords(_ template: VideoTemplate) {
        let settings = template.captionSettings
        #expect(settings.customLook == nil)
        #expect(settings.motion == CaptionMotion(playing: template.captionReveal, spec: settings.spec))
        if template.captionReveal == .line { #expect(settings.motion?.spoken == CaptionSpokenHighlight.none) }
    }

    @Test func aCutKeepsEachMarkOnItsWord() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var line = timed("I really love this", from: 1)
        line.emphasis = [2]
        edit.captions = [line]
        // The first word goes.
        edit.timeline.removeEdited(1...1.3)
        let shown = edit.editedCaptions
        #expect(shown.first?.text == "really love this")
        #expect(shown.first?.emphasis == [1], "the mark moved off \"love\"")
    }

    @Test func aLinesWayInRunsAcrossItsStates() throws {
        // Bold rises in and pops the word said: its first state is a 45 ms landing.
        let states = CaptionCollectionRenderer.overlays([timed("Make it real today")], settings: CaptionSettings(theme: .bold), position: .bottom, frame: frame)
        let start = try #require(states.first?.span?.start)
        let end = try #require(states.last?.span?.end)
        #expect(states.count > 2)
        #expect(states.allSatisfy { $0.entryStart == start && $0.exitEnd == end && $0.riseDuration > 0 })
    }

    @Test func aSavedCopyOfAStyleIsTheOnlyCardMarked() async throws {
        let styles = FakeTextStyleStore()
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: styles
        )
        await viewModel.prepare()
        viewModel.changeEdit { $0.captions = [CaptionCue(text: "Oi tudo bem", start: 1, end: 2, origin: .manual)] }
        viewModel.captions.pickCaptionTheme(.comic)
        let comic = try #require(viewModel.captions.captionCardSections(.all).flatMap(\.cards).first { $0.kind == .builtIn(.comic) })
        viewModel.captions.duplicateCaptionStyle(comic)
        #expect(viewModel.captions.captionCardSections(.all).flatMap(\.cards).filter(\.isSelected).count == 1)
        let saved = try #require(styles.captionStyles.styles.first)
        viewModel.captions.applySavedCaptionStyle(saved.id)
        let marked = viewModel.captions.captionCardSections(.all).flatMap(\.cards).filter(\.isSelected)
        #expect(marked.map(\.kind) == [.saved(saved.id)])
    }

    @Test func savedStylesANewerVersionWroteAreNeverReplaced() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        defaults.defaults.set(Data("not json".utf8), forKey: DefaultsKey.captionStyleLibrary)
        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        edit.captionCollection = CaptionSettings(theme: .pop)
        defaults.defaults.set(try? JSONEncoder().encode(MyCaptionStyle(of: edit)), forKey: DefaultsKey.myCaptionStyle)
        let read = TextStyleStore(defaults: defaults.defaults).captionStyles
        #expect(read.styles.isEmpty)
        #expect(defaults.defaults.data(forKey: DefaultsKey.captionStyleLibrary) == Data("not json".utf8))
    }
}
