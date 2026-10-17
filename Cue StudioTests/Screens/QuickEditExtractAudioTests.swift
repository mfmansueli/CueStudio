//
//  QuickEditExtractAudioTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Extract audio: a clip's sound (as Studio Voice treats it, at the clip's speed) or a video's goes to the music track where
/// it played, editable, never ducking, and the clip or the video is muted; one Undo brings both back; a cut before it brings
/// it along, like a sound effect.
@MainActor
@Suite("Quick edit extract audio")
struct QuickEditExtractAudioTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor, player: player, toast: toast)
    }

    @Test func aClipsSoundGoesToItsOwnTrackAndTheClipIsMuted() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.cut()
        var timeline = viewModel.edit.timeline
        var second = timeline.segments[1]
        second.speed = 2
        second.volume = 1.4
        second.keepsPitch = false
        timeline.replaceSegment(second)
        viewModel.commit(timeline)
        viewModel.selection = .clip(second.id)
        let steps = viewModel.history.past.count
        let unmuted = viewModel.edit.timeline
        await viewModel.extractAudio()
        let request = try #require(scenario.editor.extractions.first)
        #expect(request.span == second.span && request.speed == 2 && !request.keepsPitch)
        // The sound as the edit plays it: Studio Voice's treatment of the take.
        #expect(request.treatment?.recording == nil && request.treatment?.edit.timeline == unmuted)
        let clip = try #require(viewModel.edit.music.first)
        #expect(clip.extractedFrom == .clip)
        #expect(abs(clip.start - 10) < 0.000_1 && abs(clip.length - 27) < 0.000_1)
        #expect(clip.volume == 1.4 && !clip.ducksUnderVoice && clip.fadeIn == 0 && clip.fadeOut == 0)
        #expect(clip.title == "Sound · Clip 2")
        #expect(viewModel.edit.timeline.segment(id: second.id)?.isMuted == true)
        #expect(viewModel.selection == .music(clip.id))
        #expect(viewModel.history.past.count == steps + 1)
        #expect(scenario.toast.message == "Sound on its own track · the clip is muted")
        viewModel.undo()
        #expect(viewModel.edit.music.isEmpty)
        #expect(viewModel.edit.timeline.segment(id: second.id)?.isMuted == false)
    }

    @Test func theExtractedSoundFollowsACutBeforeIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 30
        viewModel.cut()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[1].id)
        await viewModel.extractAudio()
        #expect(abs((viewModel.edit.music.first?.start ?? 0) - 30) < 0.000_1)
        // Five seconds cut from the first clip: the sound comes five seconds earlier, with its clip.
        var timeline = viewModel.edit.timeline
        let removed = timeline.removeEdited(5...10)
        #expect(removed)
        viewModel.commit(timeline)
        #expect(abs((viewModel.edit.music.first?.start ?? 0) - 25) < 0.01)
    }

    @Test func newMusicCanGoUnderAnExtractedSound() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        await viewModel.extractAudio()
        #expect(viewModel.edit.music.count == 1)
        scenario.player.currentTime = 3
        viewModel.addMusic(ImportedAudio(fileName: "song.m4a", title: "Song", duration: 20))
        #expect(viewModel.edit.music.count == 2)
    }

    @Test func aVideoOverTheTakeGivesItsSoundAndIsMuted() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        var media = MediaOverlay(kind: .video, fileName: "broll.mov", aspect: 1, mediaDuration: 8, span: TimeSpan(start: 4, end: 7))
        media.mediaStart = 2
        media.hasSound = true
        media.audioVolume = 0.6
        viewModel.change { $0.media = [media] }
        viewModel.selection = .media(media.id)
        #expect(viewModel.toolbarItems.map(\.id).contains("extractAudio"))
        await viewModel.extractAudio()
        let request = try #require(scenario.editor.extractions.first)
        #expect(request.span == TimeSpan(start: 2, end: 5) && request.treatment == nil)
        let clip = try #require(viewModel.edit.music.first)
        #expect(clip.extractedFrom == .media && abs(clip.start - 4) < 0.000_1 && clip.volume == 0.6)
        #expect(viewModel.edit.media.first?.audioVolume == nil)
    }

    @Test func aPhotoOrASilentVideoHasNoSoundToExtract() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        var silent = MediaOverlay(kind: .video, fileName: "quiet.mov", aspect: 1, mediaDuration: 8, span: TimeSpan(start: 4, end: 7))
        silent.hasSound = false
        viewModel.change { $0.media = [silent] }
        viewModel.selection = .media(silent.id)
        #expect(!viewModel.toolbarItems.map(\.id).contains("extractAudio"))
        viewModel.perform(.selectClipAtPlayhead)
        scenario.editor.extractionHasNoSound = true
        await viewModel.extractAudio()
        #expect(viewModel.edit.music.isEmpty)
        #expect(scenario.toast.message == "This clip has no sound")
    }

    @Test func aMutedClipOrVideoHasNothingToExtract() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        await viewModel.extractAudio()
        #expect(viewModel.edit.music.count == 1)
        // A second time the clip is muted: its sound would play twice.
        viewModel.perform(.selectClipAtPlayhead)
        await viewModel.extractAudio()
        #expect(viewModel.edit.music.count == 1 && scenario.editor.extractions.count == 1)
        #expect(scenario.toast.message == "This clip is muted · Turn its sound on to extract it")
        var video = MediaOverlay(kind: .video, fileName: "loud.mov", aspect: 1, mediaDuration: 8, span: TimeSpan(start: 4, end: 7))
        video.hasSound = true
        viewModel.change { $0.media = [video] }
        viewModel.selection = .media(video.id)
        await viewModel.extractAudio()
        #expect(viewModel.edit.music.count == 1 && scenario.editor.extractions.count == 1)
        #expect(scenario.toast.message == "This video is muted · Turn its sound on to extract it")
    }

    @Test func aCutWhileExtractingAddsNothing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.selectClipAtPlayhead)
        scenario.editor.whileExtracting = {
            scenario.player.currentTime = 20
            viewModel.cut()
        }
        await viewModel.extractAudio()
        #expect(viewModel.edit.music.isEmpty)
        #expect(scenario.toast.message == "The video changed meanwhile · Extract the sound again")
    }
}
