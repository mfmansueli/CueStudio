//
//  QuickEditMediaNamesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Canvas 2 delivery 6 (owner, 07/11/2026): a photo's or video's Duration offers common lengths and a run of − or + is one
/// undo step (R12); a video's panel is Show | Part and a photo's has no part (F5); the hint after adding a video with sound
/// points at the button that is there, Volume on a window's bar or Sound on a split screen support's (bug 12); Motion shows
/// Pop first, with nothing saved changing (F15).
@MainActor
@Suite("Quick edit · media, durations and names")
struct QuickEditMediaNamesTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: player, mediaImporter: FakeMediaImporter(),
            recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    private func video(_ seconds: TimeInterval, sound: Bool) -> MediaPick {
        MediaPick(ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 16.0 / 9, duration: seconds, hasSound: sound))
    }

    @Test func commonLengthsStopAtHowLongItCanShow() {
        #expect(PanelStepper.commonLengths(upTo: .greatestFiniteMagnitude) == [1, 2, 3, 5, 10])
        #expect(PanelStepper.commonLengths(upTo: 4) == [1, 2, 3])
        #expect(PanelStepper.commonLengths(upTo: 0.5).isEmpty)
    }

    @Test func aVideoHasAPartAndAPhotoHasNone() {
        let clip = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 1, mediaDuration: 8, span: TimeSpan(start: 0, end: 4))
        let still = MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 0, end: 4))
        #expect(MediaPanel.hasPart(clip))
        #expect(!MediaPanel.hasPart(still))
        #expect(EditorPanelTab.media == [.show, .part])
    }

    @Test func theSoundHintPointsAtTheButtonThatIsThere() async throws {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 5)
        await viewModel.overlays.add([video(4, sound: true)], as: .window)
        let window = try #require(viewModel.edit.media.last?.id)
        #expect(viewModel.overlays.soundChoiceHint(for: window) == "You can change it later in Volume, on the media’s bar.")
        player.seek(to: 20)
        await viewModel.overlays.add([video(4, sound: true)], as: .split)
        let support = try #require(viewModel.edit.media.last { $0.layout == .split }?.id)
        #expect(viewModel.overlays.soundChoiceHint(for: support) == "You can change it later in Sound, on the support’s bar.")
        // The support's bar has that Sound button.
        viewModel.selection = .media(support)
        #expect(viewModel.items(for: .media(support)).contains { $0.id == "sound" })
    }

    @Test func popComesFirstAndEveryMotionIsOffered() {
        #expect(MotionPreset.panelOrder.first == .pop)
        #expect(Set(MotionPreset.panelOrder) == Set(MotionPreset.allCases))
        #expect(MotionPreset.panelOrder.count == MotionPreset.allCases.count)
    }
}
