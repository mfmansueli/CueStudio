//
//  QuickEditOverlayBarsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The toolbars of what lies over the video, as a creator editing a react or a tutorial reaches for them: a split screen's
/// support with its layout, sound, swap and replace on screen; the main video's area with its own tools (never the support's
/// Delete or Replace); a video in a window with its sound, motion and mask on screen; Volume and Motion opening straight on
/// them; a caption's Emphasis opening its words; and how opaque a window is.
@MainActor
@Suite("Toolbars over the video")
struct QuickEditOverlayBarsTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback, ToastService) {
        var take = TestData.take(scriptID: nil)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(), drafts: FakeDraftStore(), toast: toast,
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        player.seek(to: 2)
        return (viewModel, player, toast)
    }

    private func video(sound: Bool) -> MediaPick {
        MediaPick(ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 16.0 / 9, duration: 6, hasSound: sound))
    }

    @Test func aSupportHasItsLayoutSoundSwapAndReplaceOnScreen() async throws {
        let (viewModel, _, _) = await makeViewModel()
        await viewModel.overlays.add([video(sound: true)], as: .split)
        let ids = viewModel.toolbarItems.map(\.id)
        #expect(Array(ids.prefix(4)) == ["layout", "sound", "swap", "replaceMedia"])
        #expect(!ids.contains("mask"))
        #expect(ids.last == "delete")
        viewModel.perform(.openSplitTab(.sound))
        #expect(viewModel.panel == .media)
        #expect(viewModel.overlays.splitTab == .sound)
        let before = viewModel.edit.splitScreen.layouts.first
        viewModel.perform(.swapSplit)
        #expect(viewModel.edit.splitScreen.layouts.first != before)
        viewModel.undo()
        #expect(viewModel.edit.splitScreen.layouts.first == before)
    }

    @Test func theMainVideosAreaHasItsOwnToolsAndNoneThatActOnTheSupport() async throws {
        let (viewModel, _, _) = await makeViewModel()
        await viewModel.overlays.add([video(sound: false)], as: .split)
        let support = try #require(viewModel.selectedMedia)
        viewModel.overlays.pickArea(.main, of: support.id)
        let ids = viewModel.toolbarItems.map(\.id)
        #expect(Array(ids.prefix(5)) == ["framing", "swap", "layout", "clipTools", "blurArea"])
        #expect(!ids.contains("delete"), "nothing on the main video's area deletes the support")
        #expect(viewModel.toolbarContextName == "Main video")
        viewModel.perform(.selectClipAtPlayhead)
        #expect(viewModel.selection?.clipID != nil)
    }

    @Test func aVideoInAWindowHasItsSoundMotionAndMaskOnScreen() async throws {
        let (viewModel, _, toast) = await makeViewModel()
        viewModel.overlays.addMedia(video(sound: true).imported)
        let media = try #require(viewModel.selectedMedia)
        await viewModel.overlays.setMediaLayout(media.id, .window)
        #expect(Array(viewModel.toolbarItems.map(\.id).prefix(4)) == ["editMedia", "mediaVolume", "mediaMotion", "mask"])
        viewModel.perform(.open(.volume))
        #expect(viewModel.panel == .volume)
        viewModel.overlays.setMediaSoundVolume(media.id, 0.5)
        #expect(viewModel.selectedMedia?.audioVolume == 0.5)
        viewModel.perform(.openMediaMotion)
        #expect(viewModel.panel == .motion)
        // A video without sound says so.
        viewModel.overlays.updateMedia(media.id) { $0.hasSound = false }
        viewModel.panel = nil
        viewModel.perform(.open(.volume))
        #expect(viewModel.panel == nil)
        #expect(toast.message == "This video has no sound")
    }

    @Test func emphasisOpensTheLinesWords() async throws {
        let (viewModel, _, _) = await makeViewModel()
        viewModel.changeEdit { edit in
            edit.showsCaptions = true
            edit.captions = [CaptionCue(text: "Three things nobody tells you", start: 1, end: 3)]
        }
        let line = try #require(viewModel.edit.captions.first)
        viewModel.selection = .caption(line.id)
        viewModel.perform(.emphasizeCaption)
        #expect(viewModel.panel == .captions)
        #expect(viewModel.captions.expandedLineID == line.id)
    }
}
