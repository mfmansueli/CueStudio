//
//  QuickEditCopyLookTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Copy look and Paste look between clips: the copied clip's look as it plays (the take's with its own on top), only the parts
/// picked, on one clip or every clip, in one undo step; and the clip's tools that reach the whole video say so.
@MainActor
@Suite("Quick edit copy look")
struct QuickEditCopyLookTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        // Three clips: 0–10, 10–20, 20–30.
        for cut in [10.0, 20] {
            var timeline = viewModel.edit.timeline
            timeline.split(atEdited: cut)
            viewModel.commit(timeline)
        }
        return (viewModel, player)
    }

    @Test func onlyThePickedPartsGoOnThePickedClip() async throws {
        let (viewModel, _) = await makeViewModel()
        var first = viewModel.edit.timeline.segments[0]
        var look = ClipLook()
        look.exposure = 30
        look.filter = .film
        first.look = look
        first.zoom = .pushIn
        var timeline = viewModel.edit.timeline
        timeline.replaceSegment(first)
        viewModel.commit(timeline)

        viewModel.selection = .clip(first.id)
        viewModel.perform(.copyLook)
        #expect(viewModel.canPasteLook)
        let second = viewModel.edit.timeline.segments[1].id
        viewModel.selection = .clip(second)
        viewModel.perform(.pasteLook)
        #expect(viewModel.showsPasteLook)
        viewModel.togglePasteLookPart(.zoom)
        let steps = viewModel.history.past.count
        viewModel.pasteLook(on: false)
        let pasted = try #require(viewModel.edit.timeline.segment(id: second))
        #expect(pasted.look?.exposure == 30)
        #expect(pasted.look?.filter == .film)
        #expect(pasted.zoom == nil)
        #expect(viewModel.edit.timeline.segments[2].look == nil)
        #expect(viewModel.history.past.count == steps + 1)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segment(id: second)?.look == nil)
    }

    @Test func everyClipTakesItAndTheTakesLookShowsThrough() async throws {
        let (viewModel, _) = await makeViewModel()
        // The take is warm; the first clip copies as warm even without its own.
        viewModel.changeLook { $0.warmth = 40 }
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        viewModel.copyClipLook()
        viewModel.changeLook { $0.warmth = 0 }
        viewModel.pasteLook(on: true)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.look?.warmth == 40 })
    }

    @Test func theClipsWholeVideoToolsSaySo() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        let items = viewModel.toolbarItems
        #expect(items.first { $0.id == "crop" }?.scopeBadge != nil)
        #expect(items.first { $0.id == "voice" }?.scopeBadge != nil)
        #expect(items.first { $0.id == "speed" }?.scopeBadge == nil)
        #expect(items.first { $0.id == "pasteLook" }?.style == .dimmed)
        viewModel.perform(.pasteLook)
        #expect(!viewModel.showsPasteLook)
    }

    @Test func mediaIsOnTheMainToolbar() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.selection = nil
        let media = viewModel.toolbarItems.first { $0.id == "addMedia" }
        #expect(media != nil)
        viewModel.perform(.addMediaChoice)
        #expect(viewModel.sheet == .media)
        #expect(viewModel.mediaInsertMode == .overlay)
    }
}

/// Adding a sound effect from the editor: at the playhead, over music, never ducking, one undo step.
@MainActor
@Suite("Quick edit sound effects")
struct QuickEditSoundEffectTests {
    @Test func anEffectGoesOverMusicAtThePlayhead() async throws {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        // Music fills the whole edit.
        viewModel.addMusic(ImportedAudio(fileName: "song-\(UUID().uuidString).m4a", title: "Song", duration: 60))
        player.currentTime = 12
        let steps = viewModel.history.past.count
        viewModel.addSoundEffect(.whoosh)
        let effect = try #require(viewModel.edit.music.first { $0.effect == .whoosh })
        defer { EditMediaFiles.remove([effect.fileName]) }
        #expect(abs(effect.start - 12) < 0.001)
        #expect(!effect.ducksUnderVoice)
        #expect(viewModel.edit.music.count == 2)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(EditMediaFiles.exists(effect.fileName))
        #expect(viewModel.edit.mediaFileNames.contains(effect.fileName))
    }
}
