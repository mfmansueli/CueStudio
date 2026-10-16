//
//  QuickEditCopyLookTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
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
        // A clip with a look of its own loses it for the pasted parts.
        var third = viewModel.edit.timeline.segments[2]
        var own = ClipLook()
        own.warmth = -20
        third.look = own
        var timeline = viewModel.edit.timeline
        timeline.replaceSegment(third)
        viewModel.commit(timeline)
        viewModel.pasteLook(on: true)
        // Every clip warm through the video's own setting, so Adjust on the whole video still reaches every clip.
        #expect(viewModel.edit.warmth == 40)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.look?.warmth == nil })
        #expect(viewModel.edit.timeline.segments.allSatisfy { viewModel.edit.lookSettings(for: $0).warmth == 40 })
        viewModel.undo()
        #expect(viewModel.edit.warmth == 0)
        #expect(viewModel.edit.timeline.segments[2].look?.warmth == -20)
    }

    @Test func aPasteOnOneClipKeepsOnlyWhatDiffersFromTheVideo() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.changeLook { $0.filter = .film }
        var first = viewModel.edit.timeline.segments[0]
        var look = ClipLook()
        look.exposure = 25
        first.look = look
        var timeline = viewModel.edit.timeline
        timeline.replaceSegment(first)
        viewModel.commit(timeline)
        viewModel.selection = .clip(first.id)
        viewModel.copyClipLook()
        let second = viewModel.edit.timeline.segments[1].id
        viewModel.selection = .clip(second)
        viewModel.pasteLook(on: false)
        let pasted = try #require(viewModel.edit.timeline.segment(id: second)?.look)
        #expect(pasted.exposure == 25)
        // The filter is the video's: the clip doesn't own a copy, so Filters on the whole video still changes it.
        #expect(pasted.filter == nil)
        #expect(pasted.background == nil)
    }

    @Test func theClipBarHoldsOnlyTheClipsOwnToolsAndPasteWaitsForACopy() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        let items = viewModel.toolbarItems
        // Format and Studio Voice change the whole video: they're on the main bar, not marked "All" here.
        #expect(!items.contains { $0.id == "crop" || $0.id == "voice" })
        #expect(items.allSatisfy { $0.scopeBadge == nil })
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

/// Graphics over the video: Cover Studio's arrow, circle and tag, timed and moved like a text, drawn by the same code, never
/// restyled by a type preset meant for words.
@MainActor
@Suite("Quick edit graphics")
struct QuickEditGraphicsTests {
    private func makeViewModel() async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func aGraphicIsAddedPickedAndDrawn() async throws {
        let viewModel = await makeViewModel()
        viewModel.toolMenu = .text
        #expect(viewModel.toolbarItems.contains { $0.id == "graphic.arrow" })
        viewModel.perform(.addGraphic(.tag))
        let tag = try #require(viewModel.edit.texts.first)
        #expect(tag.graphic?.kind == .tag)
        #expect(tag.text == "NEW")
        #expect(viewModel.panel == .textStyle)
        #expect(viewModel.panelTitle(.textStyle) == CoverItemKind.tag.label)
        let image = try #require(TextOverlayRenderer.image(for: tag, frameWidth: 360))
        #expect(image.size.width > 20)
        viewModel.setGraphicRotation(tag.id, degrees: 90)
        #expect(abs((viewModel.edit.texts[0].graphic?.rotation ?? 0) - .pi / 2) < 0.000_1)
        // Turned a quarter, its box turns with it.
        let turned = TextOverlayRenderer.size(for: viewModel.edit.texts[0], frameWidth: 360)
        #expect(turned.height > turned.width)
        #expect(viewModel.textBars.first?.title.hasPrefix(CoverItemKind.tag.label) == true)
    }

    @Test func aTypePresetForEveryTextLeavesGraphicsAlone() async throws {
        let viewModel = await makeViewModel()
        viewModel.addGraphic(.circle)
        viewModel.addText(.title)
        viewModel.applyPreset(.editorial, to: .allTexts)
        let circle = try #require(viewModel.edit.texts.first { $0.graphic != nil })
        #expect(circle.color == CoverItemKind.circle.defaultColor)
        #expect(circle.preset != .editorial)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.preset == .editorial)
    }

    @Test func textsSavedBeforeAreTexts() throws {
        let text = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 0, end: 2))
        let decoded = try JSONDecoder().decode(TextOverlay.self, from: JSONEncoder().encode(text))
        #expect(decoded.graphic == nil)
        var arrow = text
        arrow.graphic = TextGraphic(kind: .arrow, rotation: 0.3)
        arrow.text = ""
        #expect(!arrow.isEmpty)
        #expect(try JSONDecoder().decode(TextOverlay.self, from: JSONEncoder().encode(arrow)).graphic == arrow.graphic)
    }
}
