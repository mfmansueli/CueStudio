//
//  QuickEditGestureTrustTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// What a creator can trust under the finger (plan §7): Lock holds on the preview as on the timeline and says how to undo it;
/// a move and a pinch of one gesture are one undo step; Undo and Redo say what they took back and show it when it is out of
/// sight; Reverse and Freeze frame from the main bar say (and pick) which clip; Delete all captions asks first and isn't the
/// pinned Delete; a caption line moved along the timeline asks for a timing check.
@MainActor
@Suite("Quick edit: gestures, Lock and Undo")
struct QuickEditGestureTrustTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
        let drafts: FakeDraftStore
        let takes: TakeLibraryService
    }

    private func makeScenario(
        duration: TimeInterval = 20, drafts: FakeDraftStore = FakeDraftStore(), takes existing: TakeLibraryService? = nil
    ) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 4)
        take.duration = duration
        let takes = existing ?? TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        if existing == nil { takes.load() }
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = duration
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: drafts, toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast, drafts: drafts, takes: takes)
    }

    /// A title at `time`, picked.
    private func addText(at time: TimeInterval, _ scenario: Scenario) throws -> UUID {
        scenario.player.seek(to: time)
        scenario.viewModel.overlays.addText(.title)
        let id = try #require(scenario.viewModel.edit.texts.last?.id)
        scenario.viewModel.overlays.updateText(id) { $0.text = "Hook" }
        return id
    }

    // MARK: - Lock

    @Test func aLockedTextSaysSoWhenPickedOnThePreviewAndTheTimeline() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = try addText(at: 2, scenario)
        viewModel.selection = .text(id)
        viewModel.perform(.toggleLock)
        #expect(scenario.toast.message == "Locked in place")
        viewModel.selection = nil
        viewModel.overlays.tapText(id)
        #expect(viewModel.selection == .text(id))
        #expect(scenario.toast.message == "Locked in place")
        #expect(scenario.toast.action?.title == "Unlock")
        viewModel.selection = nil
        viewModel.tapTimeline(.item(.text, id))
        #expect(viewModel.selection == .text(id))
        #expect(scenario.toast.action?.title == "Unlock")
        // Once a pick: tapping it again, still picked, doesn't say it again.
        scenario.toast.show("Something else")
        viewModel.tapTimeline(.item(.text, id))
        #expect(scenario.toast.message == "Something else")
        // A gesture that tries to move it does, every time.
        #expect(viewModel.overlays.refusesMoving(id))
        #expect(scenario.toast.message == "Locked in place")
        // Unlock, right in the toast: an undo step, and it moves again.
        scenario.toast.action?.perform()
        #expect(!viewModel.edit.lockedLayers.contains(id))
        #expect(scenario.toast.message == "Unlocked · It moves and trims again")
    }

    @Test func aLockedTextOrPhotoStaysWhereItIsAndSaysHowToFreeIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = try addText(at: 2, scenario)
        viewModel.changeEdit { $0.lockedLayers.insert(id) }
        let before = viewModel.edit
        // VoiceOver's Move, Bigger and Turn, the preview gesture's own words.
        viewModel.overlays.nudgeOverlay(.text(id), x: 0.1, y: 0)
        viewModel.overlays.resizeOverlay(.text(id), bigger: true)
        viewModel.overlays.turnText(id, clockwise: true)
        #expect(viewModel.edit == before)
        #expect(scenario.toast.message == "Locked in place")
        #expect(scenario.toast.kind == .problem)
        #expect(viewModel.overlays.refusesMoving(id))
        // A photo the same way.
        viewModel.overlays.addMedia(ImportedMedia(kind: .photo, fileName: "lock-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
        let photo = try #require(viewModel.edit.media.last?.id)
        #expect(!viewModel.overlays.refusesMoving(photo))
        viewModel.changeEdit { $0.lockedLayers.insert(photo) }
        #expect(viewModel.overlays.refusesMoving(photo))
        // Unlocked, it moves.
        viewModel.unlock(id)
        viewModel.overlays.nudgeOverlay(.text(id), x: 0.1, y: 0)
        #expect(viewModel.edit.texts.first { $0.id == id }?.center != before.texts.first { $0.id == id }?.center)
    }

    // MARK: - One gesture, one step

    @Test func aMoveAndAPinchOfOneGestureAreOneUndoStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 2)
        viewModel.overlays.addMedia(ImportedMedia(kind: .photo, fileName: "pinch-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
        let id = try #require(viewModel.edit.media.last?.id)
        viewModel.overlays.updateMedia(id) { $0.layout = .window }
        let before = try #require(viewModel.edit.media.first { $0.id == id })
        let key = OverlaysViewModel.placeKey(id, gesture: UUID())
        viewModel.overlays.moveMedia(id, to: OverlayPoint(x: 0.3, y: 0.3), key: key)
        viewModel.overlays.resizeMedia(id, by: 1.3, key: key)
        viewModel.undo()
        let after = try #require(viewModel.edit.media.first { $0.id == id })
        #expect(after.center == before.center && after.width == before.width)
    }

    /// Two gestures one right after the other (well inside the history's 0.9 s) are still two steps.
    @Test func twoQuickGesturesAreTwoUndoSteps() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 2)
        viewModel.overlays.addMedia(ImportedMedia(kind: .photo, fileName: "two-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
        let id = try #require(viewModel.edit.media.last?.id)
        viewModel.overlays.updateMedia(id) { $0.layout = .window }
        viewModel.overlays.moveMedia(id, to: OverlayPoint(x: 0.3, y: 0.3), key: OverlaysViewModel.placeKey(id, gesture: UUID()))
        let afterFirst = try #require(viewModel.edit.media.first { $0.id == id }).center
        viewModel.overlays.moveMedia(id, to: OverlayPoint(x: 0.7, y: 0.6), key: OverlaysViewModel.placeKey(id, gesture: UUID()))
        viewModel.undo()
        #expect(viewModel.edit.media.first { $0.id == id }?.center == afterFirst)
    }

    // MARK: - Undo says what

    @Test func undoAndRedoSayWhatTheyTookBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 5)
        viewModel.clips.splitClip()
        viewModel.undo()
        #expect(scenario.toast.message == "Undid · Split")
        viewModel.redo()
        #expect(scenario.toast.message == "Redid · Split")
        viewModel.look.setAspect(.square)
        viewModel.undo()
        #expect(scenario.toast.message == "Undid · Format")
    }

    @Test func undoShowsAChangeOutOfSightAndNeverJumpsForOneInView() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = try addText(at: 15, scenario)
        viewModel.selection = nil
        // Out of view (the timeline shows about 3.4 s each side at the first zoom): the playhead goes to the text.
        scenario.player.seek(to: 1)
        viewModel.undo()
        #expect(scenario.toast.message == "Undid · Text")
        #expect(abs(scenario.player.currentTime - 15) < 0.01)
        // In view: the playhead stays.
        viewModel.redo()
        #expect(viewModel.edit.texts.first { $0.id == id }?.text == "Hook")
        scenario.player.seek(to: 14)
        viewModel.undo()
        #expect(abs(scenario.player.currentTime - 14) < 0.01)
    }

    @Test func revealGoesOnlyWhereTheTimelineDoesntShow() {
        let span = TimeSpan(start: 10, end: 12)
        #expect(QuickEditViewModel.revealTime(of: span, playhead: 11, zoom: 1, duration: 20) == nil)
        #expect(QuickEditViewModel.revealTime(of: span, playhead: 13, zoom: 1, duration: 20) == nil)
        #expect(QuickEditViewModel.revealTime(of: span, playhead: 2, zoom: 1, duration: 20) == 10)
        // Zoomed in, less shows: the same distance is out of view.
        #expect(QuickEditViewModel.revealTime(of: span, playhead: 14, zoom: 4, duration: 20) == 10)
    }

    @Test func aStepIsNamedByTheToolsOwnWord() {
        let edit = TakeEdit(sourceDuration: 10, aspect: .square)
        var split = edit
        _ = split.timeline.split(atEdited: 4)
        #expect(EditStepSummary(from: edit, to: split).name == "Split")
        #expect(EditStepSummary(from: split, to: edit).name == "Split")
        #expect(abs((EditStepSummary(from: edit, to: split).span?.start ?? -1)) < 0.001)
        var trimmed = split
        _ = trimmed.timeline.trimSegment(id: split.timeline.segments[1].id, edge: .end, toSource: 8)
        let summary = EditStepSummary(from: split, to: trimmed)
        #expect(summary.name == "Clip 2")
        #expect(abs((summary.span?.start ?? -1) - 4) < 0.001)
        var locked = edit
        locked.lockedLayers.insert(UUID())
        #expect(EditStepSummary(from: edit, to: locked) == EditStepSummary(name: "Lock", span: nil))
    }

    // MARK: - The clip under the playhead

    @Test func freezeFramePicksTheFrozenClipSoItsEndCanBeDragged() async throws {
        let scenario = await makeScenario(duration: 10)
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 4)
        await viewModel.clips.freezeFrame()
        let frozen = try #require(viewModel.edit.timeline.segments.dropFirst().first)
        #expect(viewModel.selection == .clip(frozen.id))
    }

    @Test func reverseFromTheMainBarPicksTheClipUnderThePlayhead() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 5)
        viewModel.clips.splitClip()
        viewModel.selection = nil
        scenario.player.seek(to: 7)
        viewModel.perform(.reverseClip)
        #expect(viewModel.selection == .clip(viewModel.edit.timeline.segments[1].id))
    }

    // MARK: - Delete all captions

    @Test func deleteAllCaptionsAsksFirstAndIsNeverThePinnedDelete() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.changeEdit { edit in
            edit.captions = [
                CaptionCue(words: [CaptionWord(text: "one", start: 1, end: 1.4)]),
                CaptionCue(words: [CaptionWord(text: "two", start: 2, end: 2.4)]),
            ]
        }
        viewModel.perform(.openMenu(.captions))
        let deleteAll = viewModel.toolbarItems.first { $0.id == "deleteAll" }
        #expect(deleteAll?.style == .destructiveAll && deleteAll?.isPinned == false && deleteAll?.systemImage == "xmark.bin")
        #expect(viewModel.toolbarItems.allSatisfy { !$0.isPinned })
        viewModel.perform(.deleteAllCaptions)
        #expect(viewModel.captions.confirmsDeletingAll)
        #expect(viewModel.edit.captions.count == 2)
        // A picked line's Delete stays pinned, and deletes that line only.
        viewModel.selection = .caption(viewModel.edit.captions[0].id)
        #expect(viewModel.toolbarItems.last.map { $0.id == "delete" && $0.isPinned } == true)
    }

    // MARK: - Captions moved on the timeline

    @Test func aLineMovedOffItsVoiceAsksForATimingCheckInTheSameStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let heard = CaptionCue(words: [CaptionWord(text: "hi", start: 2, end: 2.3), CaptionWord(text: "there", start: 2.4, end: 2.8)])
        viewModel.changeEdit { $0.captions = [heard] }
        let line = try #require(viewModel.captions.captionMap.instances.first?.line.id)
        viewModel.selection = .caption(line)
        viewModel.beginTimelineHandle(.move(.caption, line), snapTimes: [])
        viewModel.moveTimelineHandle(by: 1.5)
        viewModel.endTimelineHandle()
        let moved = try #require(viewModel.edit.captions.first)
        #expect(abs(moved.start - 3.5) < 0.01)
        #expect(moved.needsTimingReview)
        #expect(scenario.toast.message == "Line moved · Check timing in Captions")
        viewModel.undo()
        #expect(viewModel.edit.captions == [heard])
    }

    @Test func aLineNudgedLessThanATenthSaysNothing() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let heard = CaptionCue(words: [CaptionWord(text: "hi", start: 2, end: 2.3)])
        viewModel.changeEdit { $0.captions = [heard] }
        let line = try #require(viewModel.captions.captionMap.instances.first?.line.id)
        viewModel.selection = .caption(line)
        viewModel.beginTimelineHandle(.move(.caption, line), snapTimes: [])
        viewModel.moveTimelineHandle(by: 0.05)
        viewModel.endTimelineHandle()
        #expect(viewModel.edit.captions.first?.needsTimingReview == false)
    }

    // MARK: - Done

    /// Done puts the edit on the take and ends the draft, its undo steps with it (the draft is what marks a video "in edit"):
    /// the next visit starts from the saved edit with nothing to undo. Back keeps them (`cancelKeepsADraftThatEditPicksUp`).
    @Test func doneSavesTheEditAndTheNextVisitStartsWithNothingToUndo() async {
        let drafts = FakeDraftStore()
        let first = await makeScenario(drafts: drafts)
        first.player.seek(to: 5)
        first.viewModel.clips.splitClip()
        #expect(first.viewModel.canUndo)
        first.viewModel.done()
        #expect(drafts.drafts.isEmpty)
        let second = await makeScenario(drafts: drafts, takes: first.takes)
        #expect(second.viewModel.edit.timeline.segments.count == 2)
        #expect(!second.viewModel.canUndo)
    }
}
