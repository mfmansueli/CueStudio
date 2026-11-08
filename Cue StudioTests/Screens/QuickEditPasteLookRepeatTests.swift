//
//  QuickEditPasteLookRepeatTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Paste look after the first one (owner, 07/11/2026): the sheet asks once per project, the next pastes repeat that choice where it
/// fits, every paste's toast has Undo and Change, Change takes the place of the paste just made (one Undo goes back to before
/// it), a choice that doesn't fit opens the sheet again, and the look copied and the choice stay with the project.
@MainActor
@Suite("Quick edit paste look repeat")
struct QuickEditPasteLookRepeatTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let takes: TakeLibraryService
        let drafts: FakeDraftStore
        let toast: ToastService
    }

    /// Three clips (0–10, 10–20, 20–30); the first one has its own exposure and filter.
    private func makeScenario(
        take given: Take? = nil, drafts: FakeDraftStore = FakeDraftStore(), preferences: FakeEditorPreferencesStore = FakeEditorPreferencesStore(),
        splits: Bool = true
    ) async -> Scenario {
        var take = given ?? TestData.take(scriptID: nil, number: 3)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: drafts, toast: toast,
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            editorPreferences: preferences
        )
        await viewModel.prepare()
        if splits {
            for cut in [10.0, 20] {
                var timeline = viewModel.edit.timeline
                timeline.split(atEdited: cut)
                viewModel.commit(timeline)
            }
            var first = viewModel.edit.timeline.segments[0]
            var look = ClipLook()
            look.exposure = 30
            look.filter = .film
            first.look = look
            var timeline = viewModel.edit.timeline
            timeline.replaceSegment(first)
            viewModel.commit(timeline)
        }
        return Scenario(viewModel: viewModel, takes: takes, drafts: drafts, toast: toast)
    }

    private func clip(_ viewModel: QuickEditViewModel, _ index: Int) -> UUID {
        viewModel.edit.timeline.segments[index].id
    }

    /// Copies the first clip's look and pastes it through the sheet on the second, without its zoom: four parts.
    private func copyAndPasteOnTheSecondClip(_ viewModel: QuickEditViewModel) {
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.perform(.copyLook)
        viewModel.leaveToolbarContext()
        viewModel.selection = .clip(clip(viewModel, 1))
        viewModel.perform(.pasteLook)
        #expect(viewModel.look.showsPasteLook, "The first paste of a project asks")
        viewModel.look.togglePasteLookPart(.zoom)
        viewModel.look.pasteLook(on: false)
    }

    // MARK: - Repeating

    @Test func theFirstPasteAsksAndTheNextOnePastesTheSameChoiceWithUndoAndChange() async throws {
        let viewModel = await makeScenario().viewModel
        copyAndPasteOnTheSecondClip(viewModel)
        #expect(viewModel.edit.timeline.segments[1].look?.exposure == 30)
        #expect(viewModel.edit.pasteLookChoice == PasteLookChoice(parts: [.adjust, .skin, .filter, .background], everyClip: false))

        let third = clip(viewModel, 2)
        viewModel.selection = .clip(third)
        let steps = viewModel.document.history.past.count
        viewModel.perform(.pasteLook)
        #expect(!viewModel.look.showsPasteLook, "A choice that fits is pasted without the sheet")
        let pasted = try #require(viewModel.edit.timeline.segment(id: third)?.look)
        #expect(pasted.exposure == 30 && pasted.filter == .film)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.toast.message == "Look pasted · 4 parts")
        #expect(viewModel.toast.action?.title == "Undo")
        #expect(viewModel.toast.secondaryAction?.title == "Change")
        viewModel.toast.action?.perform()
        #expect(viewModel.edit.timeline.segment(id: third)?.look == nil)
    }

    @Test func copyingIsNotAnEditStepAndUndoKeepsTheCopy() async {
        let viewModel = await makeScenario().viewModel
        let steps = viewModel.document.history.past.count
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.look.copyClipLook()
        #expect(viewModel.document.history.past.count == steps)
        #expect(viewModel.look.canPasteLook)
        viewModel.undo()
        #expect(viewModel.look.copiedLook != nil, "Undo took the copied look away")
    }

    // MARK: - Change

    @Test func changeReplacesThePasteJustMadeAndOneUndoGoesBackToBeforeIt() async throws {
        let viewModel = await makeScenario().viewModel
        copyAndPasteOnTheSecondClip(viewModel)
        let third = clip(viewModel, 2)
        viewModel.selection = .clip(third)
        let before = viewModel.document.snapshot
        let steps = viewModel.document.history.past.count
        viewModel.perform(.pasteLook)
        #expect(viewModel.edit.timeline.segment(id: third)?.look?.exposure == 30)

        // Picked elsewhere meanwhile: Change still corrects the clip it pasted on.
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.toast.secondaryAction?.perform()
        #expect(viewModel.look.showsPasteLook)
        #expect(viewModel.look.correctsLastPaste)
        #expect(viewModel.selection == .clip(third))
        #expect(viewModel.look.pastesLookParts == [.adjust, .skin, .filter, .background], "Change opens on the choice just used")
        viewModel.look.togglePasteLookPart(.adjust)
        viewModel.look.pasteLook(on: false)

        let corrected = try #require(viewModel.edit.timeline.segment(id: third)?.look)
        #expect(corrected.exposure == nil, "The first paste's Adjust stayed under the correction")
        #expect(corrected.filter == .film)
        #expect(viewModel.document.history.past.count == steps + 1, "The correction is one step with the paste it replaced")
        #expect(viewModel.edit.pasteLookChoice == PasteLookChoice(parts: [.skin, .filter, .background], everyClip: false))
        viewModel.undo()
        #expect(viewModel.document.snapshot == before)
    }

    @Test func changeCanTakeThePasteToEveryClip() async {
        let viewModel = await makeScenario().viewModel
        copyAndPasteOnTheSecondClip(viewModel)
        viewModel.selection = .clip(clip(viewModel, 2))
        let before = viewModel.document.snapshot
        viewModel.perform(.pasteLook)
        viewModel.look.changeLastPaste()
        viewModel.look.pasteLook(on: true)
        #expect(viewModel.edit.exposure == 30 && viewModel.edit.filter == .film)
        #expect(viewModel.edit.timeline.segments.allSatisfy { viewModel.edit.lookSettings(for: $0).exposure == 30 })
        #expect(viewModel.edit.pasteLookChoice?.everyClip == true)
        viewModel.undo()
        #expect(viewModel.document.snapshot == before)
    }

    @Test func changeAfterAnotherStepPastesAsANewStep() async {
        let viewModel = await makeScenario().viewModel
        copyAndPasteOnTheSecondClip(viewModel)
        viewModel.selection = .clip(clip(viewModel, 2))
        viewModel.perform(.pasteLook)
        viewModel.changeEdit { $0.volume = 0.5 }
        let steps = viewModel.document.history.past.count
        viewModel.look.changeLastPaste()
        #expect(viewModel.look.showsPasteLook)
        #expect(!viewModel.look.correctsLastPaste)
        viewModel.look.pasteLook(on: true)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.edit.volume == 0.5, "Change undid a step that wasn't the paste")
    }

    // MARK: - Not fitting

    @Test func aChoiceThatChangesNothingOnTheTargetOpensTheSheetAgain() async {
        let viewModel = await makeScenario().viewModel
        copyAndPasteOnTheSecondClip(viewModel)
        // The clip already pasted on, and the clip the look came from, already have these parts.
        for index in [1, 0] {
            viewModel.selection = .clip(clip(viewModel, index))
            let steps = viewModel.document.history.past.count
            viewModel.perform(.pasteLook)
            #expect(viewModel.look.showsPasteLook, "Clip \(index + 1): a paste that would do nothing opens the sheet")
            #expect(viewModel.look.pastesLookParts == [.adjust, .skin, .filter, .background])
            #expect(!viewModel.look.correctsLastPaste)
            #expect(viewModel.document.history.past.count == steps)
            viewModel.look.showsPasteLook = false
        }
    }

    @Test func everyClipRememberedGoesOnThePickedClipOnly() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.look.copyClipLook()
        viewModel.look.askToPasteLook()
        viewModel.look.pasteLook(on: true)
        #expect(viewModel.edit.pasteLookChoice?.everyClip == true)
        // The third clip gets a look of its own; a new copy of the first, pasted on the third, leaves the second as it is.
        let third = clip(viewModel, 2)
        viewModel.selection = .clip(third)
        viewModel.perform(.openLook(.adjust, wholeVideo: false))
        viewModel.look.setAdjustment(.contrast, -10)
        viewModel.closePanel()
        let second = viewModel.edit.timeline.segments[1]
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.look.copyClipLook()
        viewModel.selection = .clip(third)
        viewModel.look.askToPasteLook()
        #expect(!viewModel.look.showsPasteLook)
        #expect(viewModel.edit.timeline.segment(id: third)?.look?.contrast == nil)
        #expect(viewModel.edit.timeline.segments[1] == second)
        #expect(viewModel.toast.message == "Look pasted · 5 parts")
        #expect(viewModel.edit.pasteLookChoice?.everyClip == false)
    }

    @Test func theRuleOfWhatFits() async throws {
        let viewModel = await makeScenario().viewModel
        let edit = viewModel.edit
        let copied = CopiedClipLook(of: edit.timeline.segments[0], in: edit)
        let onClip = PasteLookChoice(parts: [.adjust], everyClip: false)
        let onEvery = PasteLookChoice(parts: [.adjust], everyClip: true)
        let second = edit.timeline.segments[1].id
        #expect(onClip.repeated(on: second, of: copied, in: edit) == onClip)
        #expect(onEvery.repeated(on: second, of: copied, in: edit) == onClip, "A picked clip takes it alone")
        #expect(onEvery.repeated(on: nil, of: copied, in: edit) == onEvery)
        #expect(onClip.repeated(on: nil, of: copied, in: edit) == nil, "No clip to paste on")
        #expect(onClip.repeated(on: edit.timeline.segments[0].id, of: copied, in: edit) == nil, "The clip it came from")
        #expect(onClip.repeated(on: UUID(), of: copied, in: edit) == nil, "A clip that's gone")
        #expect(PasteLookChoice(parts: [], everyClip: false).repeated(on: second, of: copied, in: edit) == nil)
        // Zoom alone, from a clip without one, changes nothing on a clip without one either.
        #expect(PasteLookChoice(parts: [.zoom], everyClip: false).repeated(on: second, of: copied, in: edit) == nil)
    }

    // MARK: - Kept with the project

    @Test func doneKeepsTheCopyAndTheChoiceOnTheTakeAndTheyReadBack() async throws {
        let first = await makeScenario()
        copyAndPasteOnTheSecondClip(first.viewModel)
        let copied = first.viewModel.look.copiedLook
        first.viewModel.done()
        let saved = try #require(first.takes.takes[0].edit)
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(saved))
        #expect(read.copiedLook == copied)
        #expect(read.pasteLookChoice == PasteLookChoice(parts: [.adjust, .skin, .filter, .background], everyClip: false))

        var take = first.takes.takes[0]
        take.edit = read
        let reopened = await makeScenario(take: take, splits: false).viewModel
        #expect(reopened.look.canPasteLook)
        let third = clip(reopened, 2)
        reopened.selection = .clip(third)
        reopened.perform(.pasteLook)
        #expect(!reopened.look.showsPasteLook, "Reopened, the choice is still known")
        #expect(reopened.edit.timeline.segment(id: third)?.look?.exposure == 30)
    }

    /// Copying alone isn't a change (owner, 08/11/2026): no unsaved change, no draft, no "Draft saved"; the look is there when the
    /// project opens again, and pasting it is the change that asks for a draft.
    @Test func copyingAloneLeavesNoDraftAndTheLookComesBack() async throws {
        let drafts = FakeDraftStore()
        let preferences = FakeEditorPreferencesStore()
        let first = await makeScenario(drafts: drafts, preferences: preferences, splits: false)
        first.viewModel.selection = .clip(clip(first.viewModel, 0))
        first.viewModel.perform(.copyLook)
        let copied = try #require(first.viewModel.look.copiedLook)
        #expect(!first.viewModel.hasUnsavedChanges)
        #expect(first.viewModel.cancel())
        #expect(drafts.drafts.isEmpty)
        #expect(first.toast.message != "Draft saved")
        #expect(first.takes.takes[0].edit == nil, "Copying marked the take edited")

        let reopened = await makeScenario(take: first.takes.takes[0], drafts: drafts, preferences: preferences, splits: false)
        let viewModel = reopened.viewModel
        #expect(viewModel.look.copiedLook == copied)
        #expect(!viewModel.hasUnsavedChanges)
        // Pasting is a change: now leaving keeps a draft.
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 15)
        viewModel.commit(timeline)
        viewModel.selection = .clip(clip(viewModel, 1))
        viewModel.change { snapshot in
            var plain = snapshot.timeline.segments[1]
            plain.look = ClipLook()
            plain.look?.exposure = -40
            snapshot.timeline.replaceSegment(plain)
        }
        viewModel.perform(.pasteLook)
        viewModel.look.pasteLook(on: false)
        #expect(viewModel.hasUnsavedChanges)
        #expect(viewModel.cancel())
        #expect(drafts.drafts.count == 1)
    }

    /// A freeze frame takes a look like any clip.
    @Test func aFreezeFrameTakesTheLook() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.perform(.copyLook)
        viewModel.leaveToolbarContext()
        viewModel.player.seek(to: 15)
        await viewModel.clips.freezeFrame()
        let frozen = try #require(viewModel.edit.timeline.segments.first { segment in
            viewModel.edit.sources.contains { $0.id == segment.sourceID && $0.still != nil }
        })
        viewModel.selection = .clip(frozen.id)
        viewModel.perform(.pasteLook)
        viewModel.look.pasteLook(on: false)
        let pasted = try #require(viewModel.edit.timeline.segment(id: frozen.id))
        #expect(pasted.look?.exposure == 30)
        #expect(pasted.look?.filter == .film)
    }

    /// A photo over the video has no look yet: Paste look there is dimmed, says where a look goes, and changes nothing (no undo
    /// step, nothing to save); the photo and the copied look stay.
    @Test func pasteLookOnAPhotoSaysWhereALookGoesAndChangesNothing() async throws {
        let scenario = await makeScenario(splits: false)
        let viewModel = scenario.viewModel
        viewModel.selection = .clip(clip(viewModel, 0))
        viewModel.perform(.copyLook)
        viewModel.leaveToolbarContext()
        let photo = MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 2, end: 6))
        viewModel.change { $0.media = [photo] }
        viewModel.selection = .media(photo.id)
        let paste = try #require(viewModel.items(for: .media(photo.id)).first { $0.action == .pasteLook })
        #expect(paste.style == .dimmed)
        let before = viewModel.edit
        let steps = viewModel.document.history.past.count
        let unsaved = viewModel.hasUnsavedChanges
        viewModel.perform(.pasteLook)
        #expect(scenario.toast.message == "You can paste this look on video clips and freeze frames.")
        #expect(!viewModel.look.showsPasteLook)
        #expect(viewModel.edit == before)
        #expect(viewModel.document.history.past.count == steps)
        #expect(viewModel.hasUnsavedChanges == unsaved)
        #expect(viewModel.selection == .media(photo.id))
        #expect(viewModel.look.copiedLook != nil)
    }

    @Test func anEditSavedBeforeReadsWithNothingCopied() throws {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.exposure = 10
        let data = try JSONEncoder().encode(edit)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["copiedLook"] == nil && object["pasteLookChoice"] == nil)
        let read = try JSONDecoder().decode(TakeEdit.self, from: data)
        #expect(read == edit)
        #expect(read.copiedLook == nil && read.pasteLookChoice == nil)
    }

    @Test func aDamagedOrNewerMemoryNeverTakesTheEdit() throws {
        let edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(edit)) as? [String: Any])
        object["copiedLook"] = 5
        object["pasteLookChoice"] = ["parts": ["filter", "sparkle"], "everyClip": true]
        let read = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(read.copiedLook == nil)
        #expect(read.pasteLookChoice == PasteLookChoice(parts: [.filter], everyClip: true), "A part Cue doesn't know is left out")
        #expect(read.timeline == edit.timeline)
    }
}
