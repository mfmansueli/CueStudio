//
//  QuickEditCutoutTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The cut-out creator in Quick edit: where they stand over a new background (a gesture or a slide is one undo step, back where they
/// were recorded keeps nothing), a photo or video shown Behind you (one at a time, an undo step, the creator movable while it
/// shows), and Check the cutout (the clips it reads, its moments in the edit's seconds, Go there, a check that no longer matches
/// the edit).
@MainActor
@Suite("Quick edit cutout")
struct QuickEditCutoutTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let checker: FakeCutoutChecker
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let checker = FakeCutoutChecker()
        viewModel.look.cutoutChecker = checker
        viewModel.look.canFindPeople = true
        return Scenario(viewModel: viewModel, player: player, checker: checker)
    }

    /// A photo from 4 to 9 s of the take.
    private func addPhoto(_ viewModel: QuickEditViewModel, from start: TimeInterval = 4, to end: TimeInterval = 9) -> UUID {
        let photo = MediaOverlay(
            kind: .photo, fileName: "beach-\(UUID().uuidString).jpg", aspect: 1.5, mediaDuration: nil, span: TimeSpan(start: start, end: end)
        )
        viewModel.look.changeEdit { $0.media.append(photo) }
        return photo.id
    }

    // MARK: - Where the creator stands

    @Test func theCreatorMovesOnlyOverSomethingNew() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.background))
        #expect(!viewModel.look.canPlacePerson)
        #expect(!viewModel.showsPersonPlace)
        viewModel.look.setBackgroundStyle(.color)
        #expect(viewModel.look.canPlacePerson)
        #expect(viewModel.showsPersonPlace)
    }

    @Test func aGestureIsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.background))
        viewModel.look.setBackgroundStyle(.color)
        viewModel.beginPanelChange()
        for step in 1...5 {
            viewModel.look.setPersonPlacement(PersonPlacement(center: OverlayPoint(x: 0.5 - Double(step) * 0.05, y: 0.6), scale: 0.8))
        }
        viewModel.endPanelChange()
        let moved = viewModel.edit.background(for: nil)?.person
        #expect(moved == PersonPlacement(center: OverlayPoint(x: 0.25, y: 0.6), scale: 0.8))
        viewModel.undo()
        #expect(viewModel.edit.background(for: nil)?.person == nil)
        #expect(viewModel.edit.background(for: nil)?.style == .color)
        viewModel.redo()
        #expect(viewModel.edit.background(for: nil)?.person == moved)
    }

    @Test func backWhereYouWereRecordedKeepsNothing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.blur)
        viewModel.look.setPersonPlacement(PersonPlacement(center: .center, scale: 0.6))
        #expect(viewModel.look.currentBackground.movesPerson)
        viewModel.look.resetPersonPlacement()
        #expect(viewModel.look.currentBackground.person == nil)
        // Sliding back to the recorded size keeps nothing either.
        viewModel.look.setPersonPlacement(PersonPlacement(center: .center, scale: 0.6))
        viewModel.look.setPersonPlacement(.asRecorded)
        #expect(viewModel.look.currentBackground.person == nil)
    }

    @Test func aClipKeepsItsOwnPlace() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.color)
        scenario.player.seek(to: 10)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        viewModel.panel = nil
        viewModel.selection = .clip(viewModel.edit.timeline.segments[1].id)
        viewModel.perform(.open(.background))
        viewModel.look.setPersonPlacement(PersonPlacement(center: OverlayPoint(x: 0.7, y: 0.5), scale: 1))
        #expect(viewModel.edit.timeline.segments[1].look?.background?.person?.center.x == 0.7)
        #expect(viewModel.edit.background(for: nil)?.person == nil)
    }

    // MARK: - Behind you

    @Test func aPhotoGoesBehindYouAsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = addPhoto(viewModel)
        viewModel.selection = .media(id)
        viewModel.overlays.setMediaBehind(id, true)
        #expect(viewModel.edit.media.first?.layout == .behind)
        viewModel.perform(.open(.media))
        #expect(viewModel.panelSubtitle(.media) == "Behind you · you stay on top")
        #expect(viewModel.showsPersonPlace)
        // While it shows, the creator can move with an Original background.
        scenario.player.seek(to: 5)
        #expect(viewModel.look.canPlacePerson)
        scenario.player.seek(to: 12)
        #expect(!viewModel.look.canPlacePerson)
        viewModel.undo()
        #expect(viewModel.edit.media.first?.layout == .fullFrame)
    }

    @Test func oneThingAtATimeBehindYou() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = addPhoto(viewModel, from: 2, to: 8)
        let second = addPhoto(viewModel, from: 6, to: 12)
        let apart = addPhoto(viewModel, from: 14, to: 18)
        viewModel.overlays.setMediaBehind(first, true)
        viewModel.overlays.setMediaBehind(apart, true)
        viewModel.overlays.setMediaBehind(second, true)
        let layouts = viewModel.edit.media.map(\.layout)
        #expect(layouts == [.behind, .fullFrame, .behind])
        #expect(viewModel.toast.message == "Something else is behind you then · one at a time")
    }

    // MARK: - Check the cutout

    @Test func checkReadsTheClipsTheCutoutIsUsedOn() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(!viewModel.look.canCheckCutout, "nothing cuts the creator out yet")
        viewModel.look.setBackgroundStyle(.blur)
        #expect(viewModel.look.canCheckCutout)
        viewModel.look.setBackgroundCutout(.colorKey)
        #expect(!viewModel.look.canCheckCutout, "a green screen has nothing to check")
        viewModel.look.setBackgroundCutout(.person)
        viewModel.look.canFindPeople = false
        #expect(!viewModel.look.canCheckCutout, "this iPhone can't find people")
        viewModel.look.canFindPeople = true
        // An Original background with a photo Behind you: the clips under it are read.
        viewModel.look.setBackgroundStyle(.original)
        #expect(!viewModel.look.canCheckCutout)
        viewModel.overlays.setMediaBehind(addPhoto(viewModel), true)
        #expect(viewModel.look.canCheckCutout)
    }

    @Test func theMomentsFoundAreInTheEditsSecondsAndATapAway() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.blur)
        // The first 4 s cut: a failure at 6 s of the recording plays at 2 s of the edit.
        viewModel.look.changeEdit { $0.timeline.trimStart(to: 4) }
        scenario.checker.failures = [TimeSpan(start: 6, end: 6.5), TimeSpan(start: 1, end: 2)]
        viewModel.look.checkCutout()
        #expect(viewModel.look.shownCutoutCheck == .checking(progress: 0))
        await viewModel.look.cutoutCheckTask?.value
        guard case .checked(let misses, _) = viewModel.look.shownCutoutCheck else {
            Issue.record("the check didn't finish: \(viewModel.look.shownCutoutCheck)")
            return
        }
        #expect(misses.count == 1)
        let miss = try #require(misses.first)
        #expect(abs(miss.start - 2) < 0.001 && abs(miss.end - 2.5) < 0.001)
        #expect(scenario.checker.asked.map(\.span) == [TimeSpan(start: 4, end: 20)])
        viewModel.look.goToCutoutMiss(miss)
        #expect(abs(scenario.player.currentTime - 2.05) < 0.001)
        #expect(!scenario.player.isPlaying)
        // The edit changed: what was found is of another edit.
        viewModel.look.updateBackground { $0.blur = 0.9 }
        #expect(viewModel.look.shownCutoutCheck == .idle)
    }

    @Test func aCheckThatFindsNothingOrFailsSaysSo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.color)
        viewModel.look.checkCutout()
        await viewModel.look.cutoutCheckTask?.value
        if case .checked(let misses, _) = viewModel.look.shownCutoutCheck {
            #expect(misses.isEmpty)
        } else {
            Issue.record("expected an empty check, got \(viewModel.look.shownCutoutCheck)")
        }
        scenario.checker.fails = true
        viewModel.look.updateBackground { $0.color = .blue }
        viewModel.look.checkCutout()
        await viewModel.look.cutoutCheckTask?.value
        #expect(viewModel.look.shownCutoutCheck == .failed)
    }

    @Test func stopKeepsNothing() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.look.setBackgroundStyle(.color)
        viewModel.look.checkCutout()
        viewModel.look.cancelCutoutCheck()
        #expect(viewModel.look.shownCutoutCheck == .idle)
        #expect(viewModel.look.cutoutCheckTask == nil)
    }
}
