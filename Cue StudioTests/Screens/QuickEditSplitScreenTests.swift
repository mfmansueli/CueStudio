//
//  QuickEditSplitScreenTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The split screen in the editor: picks go in one after the other from the playhead in one undo step, silent, never making
/// the video longer (what doesn't fit is shortened or left out, and said); one support at a time, and never a fourth photo or
/// video over the same moment; a support splits, its gap
/// closes, its start trims its part with it; the layout and each area's framing change as undo steps, the main video's
/// framing kept per recording and apart from the whole frame's; a clip in the sequence goes in at the playhead; a dragged
/// caption sticks to the seam, and one dragged off it says so, with the way back.
@MainActor
@Suite("Split screen in the editor")
struct QuickEditSplitScreenTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    /// A 64 s take; `hook` runs while the first face is found.
    private func makeScenario(hook: FakeFaceFinderHook? = nil) async -> Scenario {
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
            recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), faceFinder: FakeFaceFinder(hook: hook)
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

    // MARK: - While the faces are found

    /// A support goes in once its face is found, on the edit as it is then: a text added meanwhile stays, as its own step.
    @Test func aChangeMadeWhileTheFaceIsFoundStays() async {
        let hook = FakeFaceFinderHook()
        let scenario = await makeScenario(hook: hook)
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        hook.whileFinding = { viewModel.overlays.addText(.callout) }
        await viewModel.overlays.add([video(4)], as: .split)
        #expect(viewModel.edit.texts.count == 1)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 14)])
        viewModel.undo()
        #expect(viewModel.edit.media.isEmpty)
        #expect(viewModel.edit.texts.count == 1)
    }

    /// An Undo made while the face is found stays undone: the support never writes back an older edit.
    @Test func anUndoMadeWhileTheFaceIsFoundStaysUndone() async {
        let hook = FakeFaceFinderHook()
        let scenario = await makeScenario(hook: hook)
        let viewModel = scenario.viewModel
        viewModel.overlays.addText(.callout)
        scenario.player.seek(to: 10)
        hook.whileFinding = { viewModel.undo() }
        await viewModel.overlays.add([video(4)], as: .split)
        #expect(viewModel.edit.texts.isEmpty)
        #expect(spans(viewModel) == [TimeSpan(start: 10, end: 14)])
    }

    /// A cut made while the face is found would put the support somewhere else: nothing goes in, and it says so.
    @Test func aCutMadeWhileTheFaceIsFoundAddsNothing() async {
        let hook = FakeFaceFinderHook()
        let scenario = await makeScenario(hook: hook)
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        hook.whileFinding = {
            var timeline = viewModel.edit.timeline
            timeline.split(atEdited: 30)
            viewModel.commit(timeline)
        }
        await viewModel.overlays.add([video(4)], as: .split)
        #expect(viewModel.edit.media.isEmpty)
        #expect(viewModel.edit.timeline.segments.count == 2)
        #expect(scenario.toast.message == "The video changed meanwhile · Add it again")
    }

    /// A support put in the split screen meanwhile keeps its place: the second never goes over it.
    @Test func aSupportPutThereWhileTheFaceIsFoundKeepsItsPlace() async {
        let hook = FakeFaceFinderHook()
        let scenario = await makeScenario(hook: hook)
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        let first = video(4)
        hook.whileFinding = { await viewModel.overlays.add([first], as: .split) }
        await viewModel.overlays.add([video(6)], as: .split)
        #expect(viewModel.edit.media.map(\.fileName) == [first.imported.fileName])
        #expect(scenario.toast.message == "Another support shows then · one at a time in the split screen")
    }

    /// Changing how a video shows finds its face first: a change made meanwhile stays, and of two layouts tapped quickly the
    /// last wins.
    @Test func aLayoutChangeKeepsWhatChangedMeanwhileAndTheLastTapWins() async throws {
        let hook = FakeFaceFinderHook()
        let scenario = await makeScenario(hook: hook)
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4, sound: true)], as: .window)
        let id = try #require(viewModel.edit.media.first?.id)
        hook.whileFinding = { viewModel.change { $0.media[0].audioVolume = 0.5 } }
        await viewModel.overlays.setMediaLayout(id, .split)
        #expect(viewModel.edit.media.first?.layout == .split)
        #expect(viewModel.edit.media.first?.audioVolume == 0.5)
        // Another video, whose face is still to be found.
        scenario.player.seek(to: 30)
        await viewModel.overlays.add([video(4)], as: .window)
        let other = try #require(viewModel.edit.media.last?.id)
        hook.whileFinding = { await viewModel.overlays.setMediaLayout(other, .fullFrame) }
        await viewModel.overlays.setMediaLayout(other, .split)
        #expect(viewModel.edit.media.last?.layout == .fullFrame)
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

    /// The export draws three photos or videos over the video at once, and a fourth video would be left out without a word:
    /// a support counts like a window, said before picking and refused after (the reviewer's case, 25/10).
    @Test func aSupportNeverMakesAFourthOverThreeWindows() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        for _ in 0..<3 {
            scenario.player.seek(to: 10)
            await viewModel.overlays.add([video(8)], as: .window)
        }
        #expect(viewModel.edit.media.count == 3)
        scenario.player.seek(to: 12)
        #expect(viewModel.overlays.insertionRoomIsShort(for: .split))
        #expect(viewModel.overlays.insertionNote(for: .split) == "3 photos or videos already show here · move the playhead")
        let steps = viewModel.document.history.past.count
        await viewModel.overlays.add([video(4)], as: .split)
        #expect(viewModel.edit.media.count == 3)
        #expect(viewModel.overlays.supportSpans.isEmpty)
        #expect(viewModel.document.history.past.count == steps)
        #expect(scenario.toast.message == "3 photos or videos already show then · up to 3 at a time" && scenario.toast.kind == .problem)
        // Starting before them and running into them: refused too.
        scenario.player.seek(to: 6)
        await viewModel.overlays.add([video(6)], as: .split)
        #expect(viewModel.overlays.supportSpans.isEmpty)
        // After them, it goes in.
        scenario.player.seek(to: 30)
        #expect(!viewModel.overlays.insertionRoomIsShort(for: .split))
        await viewModel.overlays.add([video(4)], as: .split)
        #expect(spans(viewModel) == [TimeSpan(start: 30, end: 34)])
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

    // MARK: - Captions on the seam

    @Test func aCaptionDraggedOffTheSeamSaysSoAndOneTapPutsItBack() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4)], as: .split)
        scenario.player.seek(to: 11)
        let seam = try #require(EditedComposition.splitSeams(of: viewModel.edit).first?.y)
        #expect(viewModel.edit.splitScreen.captionsOnSeam && viewModel.captions.captionY == seam)
        // Dragged up over the support: the captions go there, and the toast says they no longer sit on the seam.
        let steps = viewModel.document.history.past.count
        viewModel.captions.moveCaptions(toY: 0.38)
        #expect(!viewModel.edit.splitScreen.captionsOnSeam && viewModel.edit.captionCollection?.center?.y == 0.38)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(scenario.toast.message == "Captions stay where you put them" && scenario.toast.action?.title == "On the seam")
        // One tap puts them back on the seam while the split screen shows; elsewhere they stay where they were put.
        scenario.toast.action?.perform()
        #expect(viewModel.edit.splitScreen.captionsOnSeam && viewModel.captions.captionY == seam)
        scenario.player.seek(to: 30)
        #expect(viewModel.captions.captionY == 0.38)
    }

    @Test func aCaptionDraggedNearTheSeamSticksToItAndSitsThereAgain() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 10)
        await viewModel.overlays.add([video(4)], as: .split)
        scenario.player.seek(to: 11)
        let seam = try #require(EditedComposition.splitSeams(of: viewModel.edit).first?.y)
        viewModel.captions.moveCaptions(toY: 0.38)
        #expect(!viewModel.edit.splitScreen.captionsOnSeam)
        // Near the seam the caption sticks to it (the drag ticks there), and the option is on again, with a toast.
        let near = CaptionsViewModel.snappedCaption(seam + 0.02, seam: seam)
        #expect(near.y == seam && near.stop == seam)
        viewModel.captions.moveCaptions(toY: seam + 0.02)
        #expect(viewModel.edit.splitScreen.captionsOnSeam && viewModel.captions.captionY == seam)
        #expect(scenario.toast.message == "Captions on the seam during the split screen")
        // Its own place for the rest of the video stays where it was put.
        #expect(viewModel.edit.captionCollection?.center?.y == 0.38)
        // Dropped on the seam again, nothing changes.
        let steps = viewModel.document.history.past.count
        viewModel.captions.moveCaptions(toY: seam)
        #expect(viewModel.document.history.past.count == steps)
        // Without a split screen at the playhead there is no seam to stick to.
        scenario.player.seek(to: 30)
        #expect(viewModel.captions.splitSeamAtPlayhead == nil)
    }
}
