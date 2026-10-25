//
//  QuickEditSplitScreenTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The split screen in the editor: picks go in one after the other from the playhead in one undo step, silent, never making
/// the video longer (what doesn't fit is shortened or left out, and said); one support at a time; a support splits, its gap
/// closes, its start trims its part with it; the layout and each area's framing change as undo steps, the main video's
/// framing kept per recording and apart from the whole frame's; a clip in the sequence goes in at the playhead.
@MainActor
@Suite("Split screen in the editor")
struct QuickEditSplitScreenTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    /// A 64 s take.
    private func makeScenario() async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player, mediaImporter: FakeMediaImporter(),
            recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func video(_ seconds: TimeInterval, sound: Bool = false) -> MediaPick {
        MediaPick(ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 16.0 / 9, duration: seconds, hasSound: sound))
    }

    private func photo() -> MediaPick {
        MediaPick(ImportedMedia(kind: .photo, fileName: "p-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
    }

    private func spans(_ viewModel: QuickEditViewModel) -> [TimeSpan] {
        viewModel.overlays.supportSpans.map(\.span)
    }

    // MARK: - Adding

    @Test func severalPicksGoInOneAfterTheOtherFromThePlayheadInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4, sound: true), video(6), photo()], as: .split)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 14), TimeSpan(start: 14, end: 20), TimeSpan(start: 20, end: 23)])
        #expect(viewModel.edit.media.allSatisfy { $0.layout == .split && $0.followsCuts == true && $0.audioVolume == nil })
        #expect(viewModel.edit.splitScreen.layouts.count == 1)
        #expect(viewModel.edit.media.allSatisfy { $0.splitLayoutID == viewModel.edit.splitScreen.layouts[0].id })
        // The first split screen starts with a blurred seam and the captions on it.
        #expect(viewModel.edit.splitScreen.layouts[0].seam == .blur)
        #expect(viewModel.edit.splitScreen.captionsOnSeam)
        #expect(viewModel.selection == .media(viewModel.edit.media[0].id))
        #expect(scenario.toast.message?.contains("3 added to the split screen from 00:10.0") == true)
        #expect(scenario.toast.message?.contains("muted") == true)
        viewModel.undo()
        #expect(viewModel.edit.media.isEmpty)
    }

    @Test func littleRoomFromThePlayheadIsSaidBeforePicking() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        #expect(!viewModel.overlays.insertionRoomIsShort(for: .split))
        #expect(viewModel.overlays.insertionNote(for: .split).contains("room until"))
        // 1.6 s before the end, as in the owner's recording (25/10).
        scenario.player.seek(to: 62.4)
        #expect(viewModel.overlays.insertionRoomIsShort(for: .split))
        #expect(viewModel.overlays.insertionNote(for: .split).contains("move the playhead back"))
    }

    @Test func aVideosChosenPartGoesIn() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 5)
        var pick = video(20)
        pick.start = 3
        pick.length = 5
        await viewModel.overlays.add([pick], as: .split)
        #expect(spans(viewModel) == [TimeSpan(start: 5, end: 10)])
        #expect(viewModel.edit.media[0].mediaStart == 3)
    }

    @Test func whatDoesntFitIsShortenedOrLeftOutAndTheVideoNeverGrows() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 58)
        let picks = [video(4), video(4), video(4)]
        let run = viewModel.overlays.run(of: picks, as: .split)
        #expect(run.leftOut == 1)
        #expect(run.placed.last?.isShortened == true)
        #expect(viewModel.overlays.runNote(run, count: 3).contains("1 doesn’t fit"))
        await viewModel.overlays.add(picks, as: .split)
        #expect(spans(viewModel) == [TimeSpan(start: 58, end: 62), TimeSpan(start: 62, end: 64)])
        #expect(viewModel.edit.editedDuration == 64)
        #expect(scenario.toast.message?.contains("1 didn’t fit") == true)
    }

    @Test func aSplitStartsAfterTheSupportAtThePlayheadAndStopsBeforeTheNext() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4)], as: .split)
        scenario.player.seek(to: 30)
        await viewModel.overlays.add([video(4)], as: .split)
        // Inside the first: after it, with room up to the second.
        scenario.player.seek(to: 12)
        #expect(viewModel.overlays.runStart(for: .split) == 14)
        #expect(viewModel.overlays.runRoom(for: .split, from: 14) == 16)
        await viewModel.overlays.add([video(30)], as: .split)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 14), TimeSpan(start: 14, end: 30), TimeSpan(start: 30, end: 34)])
        // Windows can still lie over a support.
        #expect(viewModel.overlays.runRoom(for: .window, from: 12) == 52)
    }

    // MARK: - Editing a support

    @Test func splittingASupportChangesNothingThatShows() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(8)], as: .split)
        let id = viewModel.edit.media[0].id
        scenario.player.seek(to: 13)
        viewModel.selection = .media(id)
        viewModel.perform(.splitMedia)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 13), TimeSpan(start: 13, end: 18)])
        let second = try #require(viewModel.edit.media.first { $0.id != id })
        #expect(second.mediaStart == 3)
        #expect(viewModel.selection == .media(second.id))
        #expect(scenario.toast.message?.contains("Split at 00:13.0") == true)
        viewModel.undo()
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 18)])
    }

    @Test func closingAGapMovesTheNextSupportOnlyAndSaysSo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4)], as: .split)
        scenario.player.seek(to: 14.3)
        await viewModel.overlays.add([video(4), video(2)], as: .split)
        let second = viewModel.overlays.supportSpans[1].id
        #expect(abs((viewModel.overlays.gapBefore(second) ?? 0) - 0.3) < 0.001)
        viewModel.selection = .media(second)
        #expect(viewModel.toolbarItems.contains { $0.id == "closeGap" })
        viewModel.perform(.closeGap)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 14), TimeSpan(start: 14, end: 18), TimeSpan(start: 18.3, end: 20.3)])
        #expect(viewModel.overlays.gapBefore(second) == nil)
        #expect(scenario.toast.message?.contains("the speech didn’t change") == true)
    }

    @Test func trimmingTheStartKeepsEveryFrameWhereItWas() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(8)], as: .split)
        let id = viewModel.edit.media[0].id
        viewModel.overlays.trimMediaStart(id, to: 12)
        #expect(spans(viewModel) == [TimeSpan(start: 12, end: 18)])
        #expect(viewModel.edit.media[0].mediaStart == 2)
        // Back past where the file starts: only as far as it has.
        viewModel.overlays.trimMediaStart(id, to: 5)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 18)])
        #expect(viewModel.edit.media[0].mediaStart == nil)
    }

    @Test func aSupportNeverLiesOverAnother() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4)], as: .split)
        scenario.player.seek(to: 12)
        await viewModel.overlays.add([video(4)], as: .window)
        let window = viewModel.edit.media.first { $0.layout == .window }!.id
        await viewModel.overlays.setMediaLayout(window, .split)
        #expect(viewModel.edit.media.first { $0.id == window }?.layout == .window)
        #expect(scenario.toast.message?.contains("one at a time") == true)
    }

    @Test func replacingASupportKeepsItsPlaceAndSettings() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(6, sound: true)], as: .split)
        let id = viewModel.edit.media[0].id
        viewModel.overlays.setAreaFraming(AreaFraming(fit: .fit, zoom: 1.5, center: OverlayPoint(x: 0.2, y: 0.4)), for: .support, of: id)
        viewModel.overlays.setMediaSoundVolume(id, 0.6)
        viewModel.overlays.setMainVolume(id, 0.3)
        var pick = video(20, sound: true)
        pick.start = 4
        viewModel.overlays.replaceMedia(id, with: pick)
        let replaced = try #require(viewModel.edit.media.first)
        #expect(replaced.id == id && replaced.layout == .split)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 16)])
        #expect(replaced.mediaStart == 4)
        #expect(replaced.areaFraming?.fit == .fit && replaced.areaFraming?.zoom == 1.5)
        #expect(replaced.audioVolume == 0.6 && replaced.mainVolume == 0.3)
        #expect(scenario.toast.message?.contains("place and settings kept") == true)
        viewModel.undo()
        #expect(viewModel.edit.media[0].mediaStart == nil)
    }

    // MARK: - Layout and framing

    @Test func theLayoutChangesAsUndoStepsAndSwappingMovesOnlyThePlaces() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4, sound: true)], as: .split)
        let id = viewModel.edit.media[0].id
        viewModel.overlays.setMediaSoundVolume(id, 0.5)
        let before = viewModel.edit.media[0]
        viewModel.overlays.changeSplitLayout { $0.ratio = .sixtyForty }
        viewModel.overlays.swapSplit()
        #expect(viewModel.overlays.splitLayout.first == .main)
        #expect(viewModel.overlays.splitLayout.larger == .main)
        // Swapping keeps the seam.
        #expect(viewModel.overlays.splitLayout.seam == .blur)
        // The support's sound, part and timing are as they were.
        #expect(viewModel.edit.media[0] == before)
        viewModel.undo()
        #expect(viewModel.overlays.splitLayout.first == .support)
        viewModel.undo()
        #expect(viewModel.overlays.splitLayout.ratio == .even)
    }

    @Test func theMainAreasFramingIsItsRecordingsAndLeavesTheWholeFrameAlone() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4)], as: .split)
        let id = viewModel.edit.media[0].id
        let cropOffset = viewModel.edit.cropOffset
        let framing = AreaFraming(fit: .fill, zoom: 2, center: OverlayPoint(x: 0.5, y: 0.3))
        viewModel.overlays.setAreaFraming(framing, for: .main, of: id)
        #expect(viewModel.edit.splitScreen.framing(for: nil) == framing)
        #expect(viewModel.edit.cropOffset == cropOffset)
        #expect(viewModel.edit.media[0].areaFraming != framing)
        viewModel.overlays.setAreaFraming(AreaFraming(fit: .fit), for: .support, of: id)
        #expect(viewModel.edit.media[0].areaFraming?.fit == .fit)
        viewModel.undo()
        #expect(viewModel.edit.media[0].areaFraming?.fit != .fit)
    }

    @Test func theMainVideoCanBeTurnedDownOnlyWhileASupportShowsAndAllSupportsMuted() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4, sound: true)], as: .split)
        let id = viewModel.edit.media[0].id
        viewModel.overlays.setMainVolume(id, 0)
        #expect(viewModel.edit.media[0].mainVolume == 0)
        viewModel.overlays.setMainVolume(id, 1)
        #expect(viewModel.edit.media[0].mainVolume == nil)
        viewModel.overlays.setMediaSoundVolume(id, 0.8)
        viewModel.overlays.setMutesAllMedia(true)
        #expect(viewModel.edit.splitScreen.mutesMedia)
        #expect(viewModel.edit.media[0].audioVolume == 0.8)
    }

    // MARK: - In the sequence

    @Test func aClipInTheSequenceGoesInAtThePlayheadAndTheVideoGrows() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 20)
        #expect(viewModel.clips.insertionNote == "Goes in at 00:20.0 · splits clip 1")
        var pick = video(10)
        pick.start = 2
        pick.length = 5
        viewModel.clips.addClip(pick)
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 3)
        #expect(segments[0].sourceEnd == 20 && segments[2].sourceStart == 20)
        #expect(segments[1].sourceStart == 2 && segments[1].sourceEnd == 7)
        #expect(viewModel.edit.editedDuration == 69)
        #expect(scenario.toast.message?.contains("longer") == true)
    }
}
