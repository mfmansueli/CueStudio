//
//  QuickEditReplaceClipTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Replace clip: the picked clip plays a video from Photos from its start, for as long as it lasted (shorter when the video is),
/// in the same place and with its speed, zoom, volume, transition and look; what's pinned to it stays at the same moment of
/// it; one Undo brings the old recording back.
@MainActor
@Suite("Quick edit replace clip")
struct QuickEditReplaceClipTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
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
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func video(_ seconds: TimeInterval) -> ImportedMedia {
        ImportedMedia(kind: .video, fileName: "video-\(UUID().uuidString).mov", aspect: 9.0 / 16, duration: seconds, hasSound: true)
    }

    /// Cuts at 10 and 20 s and picks the middle clip, given a speed, a zoom, a volume, a transition and a look.
    private func middleClip(_ scenario: Scenario) -> UUID {
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.cut()
        scenario.player.currentTime = 20
        viewModel.cut()
        var timeline = viewModel.edit.timeline
        var middle = timeline.segments[1]
        middle.speed = 2
        middle.zoom = .punchIn
        middle.volume = 1.5
        middle.transitionIn = .dissolve
        var look = ClipLook()
        look.filter = .cinema
        middle.look = look
        timeline.replaceSegment(middle)
        viewModel.commit(timeline)
        viewModel.selection = .clip(middle.id)
        return middle.id
    }

    @Test func theClipKeepsItsPlaceLengthAndEffects() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = middleClip(scenario)
        let before = try #require(viewModel.edit.timeline.segment(id: id))
        let length = viewModel.edit.editedDuration
        let steps = viewModel.history.past.count
        viewModel.replaceClip(id, with: video(30))
        let after = try #require(viewModel.edit.timeline.segment(id: id))
        #expect(viewModel.edit.timeline.index(ofSegment: id) == 1)
        let source = try #require(viewModel.edit.sources.first { $0.id == after.sourceID })
        #expect(source.duration == 30)
        #expect(after.sourceStart == 0 && abs(after.sourceEnd - before.sourceLength) < 0.000_1)
        #expect(after.speed == 2 && after.zoom == .punchIn && after.volume == 1.5 && after.transitionIn == .dissolve)
        #expect(after.look == before.look)
        #expect(abs(viewModel.edit.editedDuration - length) < 0.000_1)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(scenario.toast.message == "Clip replaced")
        viewModel.undo()
        #expect(viewModel.edit.timeline.segment(id: id) == before)
    }

    @Test func aShorterVideoMakesTheClipShorter() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = middleClip(scenario)
        viewModel.replaceClip(id, with: video(4))
        let after = try #require(viewModel.edit.timeline.segment(id: id))
        #expect(after.sourceEnd == 4)
        #expect(abs(after.duration - 2) < 0.000_1)
        #expect(scenario.toast.message == "Clip replaced · the video is shorter, so the clip is too")
    }

    @Test func aPhotoOrATooShortVideoChangesNothing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = middleClip(scenario)
        let timeline = viewModel.edit.timeline
        viewModel.replaceClip(id, with: ImportedMedia(kind: .photo, fileName: "p.jpg", aspect: 1, duration: nil))
        #expect(scenario.toast.message == "Pick a video first")
        viewModel.replaceClip(id, with: video(0.1))
        #expect(scenario.toast.message == "Video too short to add")
        #expect(viewModel.edit.timeline == timeline)
        #expect(viewModel.edit.sources.isEmpty)
    }

    @Test func whatIsPinnedToTheClipStaysAtTheSameMomentOfIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = middleClip(scenario)
        // A text 1 s into the clip (the clip plays the take from 10 s, at 2×).
        let start = viewModel.edit.timeline.editedStart(ofSegmentAt: 1)
        let pinned = viewModel.edit.pin(TimeSpan(start: start + 1, end: start + 2))
        var text = viewModel.edit.newText(.title, span: pinned.span)
        text.clipAnchor = pinned.anchor
        text.text = "Hello"
        viewModel.change { $0.texts = [text] }
        let shown = try #require(viewModel.edit.editedTexts(in: viewModel.edit.timeline).first?.span)
        viewModel.replaceClip(id, with: video(30))
        let moved = try #require(viewModel.edit.texts.first)
        let source = try #require(viewModel.edit.timeline.segment(id: id)?.sourceID)
        #expect(moved.clipAnchor == ClipAnchor(segmentID: id, sourceID: source))
        #expect(abs(moved.span.start - 2) < 0.000_1)
        let after = try #require(viewModel.edit.editedTexts(in: viewModel.edit.timeline).first?.span)
        #expect(abs(after.start - shown.start) < 0.000_1 && abs(after.end - shown.end) < 0.000_1)
    }

    @Test func whatPlaysOnTheOtherPartOfACutClipStaysThere() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = middleClip(scenario)
        // Replacing the first clip arranges the edit, so a text placed now is pinned to its clip.
        viewModel.replaceClip(viewModel.edit.timeline.segments[0].id, with: video(30))
        // A text 3 s into the middle clip (the take from 10 s, at 2×: the take's 16 s), then the clip cut 1 s in: the text
        // plays on the right part, still pinned to the left one (a cut keeps the left part's identity).
        let start = viewModel.edit.timeline.editedStart(ofSegmentAt: 1)
        let pinned = viewModel.edit.pin(TimeSpan(start: start + 3, end: start + 4))
        #expect(pinned.anchor?.segmentID == id)
        var text = viewModel.edit.newText(.title, span: pinned.span)
        text.clipAnchor = pinned.anchor
        text.text = "Hello"
        viewModel.change { $0.texts = [text] }
        scenario.player.currentTime = start + 1
        viewModel.cut()
        let shown = try #require(viewModel.edit.editedTexts(in: viewModel.edit.timeline).first?.span)
        viewModel.replaceClip(id, with: video(30))
        #expect(viewModel.edit.texts.first?.clipAnchor == pinned.anchor)
        let after = try #require(viewModel.edit.editedTexts(in: viewModel.edit.timeline).first?.span)
        #expect(abs(after.start - shown.start) < 0.000_1 && abs(after.end - shown.end) < 0.000_1)
    }

    @Test func replaceAsksPhotosForAVideoOfThePickedClip() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = middleClip(scenario)
        viewModel.perform(.replaceClip)
        #expect(viewModel.photoRequest?.purpose == .replaceClip(id))
        #expect(viewModel.photoRequest?.offersVideos == true)
    }
}
