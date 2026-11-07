//
//  QuickEditVideoTemplateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Video templates: captions, texts and motion in one undo step; the words, the lines and the graphics stay; a hook with the
/// script's title when there was no text.
@MainActor
@Suite("Quick edit video templates")
struct QuickEditVideoTemplateTests {
    @Test func aTemplateRestylesEverythingInOneStepAndKeepsTheWords() async throws {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.change { $0.captions = [CaptionCue(text: "Real talk", start: 1, end: 2)] }
        viewModel.overlays.addGraphic(.arrow)
        let before = viewModel.edit
        let steps = viewModel.document.history.past.count
        viewModel.applyVideoTemplate(.boldHook)
        #expect(viewModel.document.history.past.count == steps + 1)
        // Bold hook's captions: heavy type on a violet band behind each line, bigger, the word being said in yellow.
        let captions = try #require(viewModel.edit.captionCollection)
        #expect(captions.theme == .pop)
        #expect(captions.customLook == nil)
        #expect(captions.accent == .yellow)
        #expect(captions.sizeScale > 1)
        #expect(viewModel.edit.captionAnimation == .highlight)
        #expect(viewModel.edit.captions == before.captions)
        // A hook with the title opens the video; the arrow is untouched.
        let hook = try #require(viewModel.edit.texts.first { $0.graphic == nil })
        #expect(hook.role == .hook)
        #expect(!hook.text.isEmpty)
        #expect(hook.animation?.preset == .pop)
        #expect(viewModel.edit.texts.first { $0.graphic != nil } == before.texts.first)
        // Another template restyles the hook, keeping its words.
        viewModel.applyVideoTemplate(.story)
        #expect(viewModel.edit.texts.filter { $0.graphic == nil }.count == 1)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.text == hook.text)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.preset == .editorial)
        #expect(viewModel.appliedVideoTemplate == .story)
        viewModel.undo()
        #expect(viewModel.appliedVideoTemplate == .boldHook)
        viewModel.undo()
        #expect(viewModel.appliedVideoTemplate == nil)
        #expect(viewModel.edit.texts == before.texts)
        #expect(viewModel.edit.captionCollection == before.captionCollection)
    }
}
