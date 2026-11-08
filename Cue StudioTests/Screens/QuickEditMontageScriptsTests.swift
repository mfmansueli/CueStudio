//
//  QuickEditMontageScriptsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A montage of a Portuguese take, a Spanish take of another script and a video brought in: Clean up hears each take against its
/// own script, in its language (the lines said more than once come from the right script), and the video with no script in the
/// take's language (owner, 07/11/2026). Captions already did.
@MainActor
@Suite("Quick edit montage: each take's own script")
struct QuickEditMontageScriptsTests {
    @Test func eachTakeIsHeardWithItsOwnScriptAndTheVideoWithNone() async throws {
        let portuguese = TestData.script(title: "Hábitos", text: "Três hábitos de manhã.\n\nO primeiro é água.", language: .portugueseBrazil)
        let spanish = TestData.script(title: "Entrevista", text: "Hoy te cuento cómo empecé.\n\nFue un error.", language: .spanish)
        let take = TestData.take(scriptID: portuguese.id, title: portuguese.title, number: 3)
        let other = TestData.take(scriptID: spanish.id, title: spanish.title, number: 2)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take, other]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [portuguese, spanish]))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 12
        let viewModel = QuickEditViewModel(
            take: try #require(takes.takes.first { $0.id == take.id }), takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let file = viewModel.takes.videoURL(for: other)
        try Data("video".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        viewModel.player.seek(to: 12)
        await viewModel.clips.addClip(from: try #require(takes.takes.first { $0.id == other.id }))
        viewModel.player.seek(to: viewModel.edit.editedDuration)
        let video = ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 16.0 / 9, duration: 6, hasSound: true)
        viewModel.clips.addClip(MediaPick(video))
        defer { EditMediaFiles.remove(Set(viewModel.edit.sources.map(\.fileName))) }
        let sources = viewModel.edit.sources
        #expect(sources.count == 2)

        await viewModel.clips.analyzeIfNeeded()
        let takeFile = viewModel.videoURL
        let otherFile = EditMediaFiles.url(for: try #require(sources.first { $0.takeID == other.id }).fileName)
        let videoFile = EditMediaFiles.url(for: try #require(sources.first { $0.takeID == nil }).fileName)
        #expect(editor.cleanUpScripts[takeFile] == portuguese.text)
        #expect(editor.cleanUpScripts[otherFile] == spanish.text)
        #expect(editor.cleanUpScripts[videoFile] == "")
        #expect(editor.cleanUpLanguages[takeFile] == .language(.portugueseBrazil))
        #expect(editor.cleanUpLanguages[otherFile] == .language(.spanish))
        #expect(editor.cleanUpLanguages[videoFile] == .language(.portugueseBrazil))
    }
}
