//
//  QuickEditTimelineTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Quick edit timeline")
struct QuickEditTimelineTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
    }

    private func makeScenario(duration: TimeInterval = 21.6) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = duration
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = duration
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player)
    }

    /// Three clips: 0–7.1, 7.1–10.1 ("não, pera"), 10.1–21.6.
    private func split(_ scenario: Scenario) {
        scenario.player.seek(to: 7.1)
        scenario.viewModel.selectClipAtPlayhead()
        scenario.viewModel.splitClip()
        scenario.player.seek(to: 10.1)
        scenario.viewModel.splitClip()
        scenario.viewModel.selection = nil
    }

    // MARK: - What it shows

    @Test func theInputFollowsTheEdit() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        let segments = viewModel.edit.timeline.segments
        var timeline = viewModel.edit.timeline
        var middle = segments[1]
        middle.speed = 1.5
        middle.zoom = .pushIn
        middle.isMuted = true
        timeline.replaceSegment(middle)
        viewModel.edit.timeline = timeline
        let input = viewModel.timelineInput(heightClass: .regular)
        #expect(input.clips.map(\.start) == [0, 7.1, 9.1])
        let speed = 1.5.formatted(.number.precision(.fractionLength(0...2)).locale(.interface)) + "×"
        #expect(input.clips[1].badge == "\(speed) · Push in · Muted")
        #expect(input.clips[0].badge == nil)
        #expect(abs(input.duration - 20.6) < 0.000_1)
        #expect(input.pointsPerSecond == 44)
    }

    @Test func aPanelMakesTheTimelineCompactAndFocused() async {
        let viewModel = await makeScenario().viewModel
        viewModel.panel = .captions
        let input = viewModel.timelineInput(heightClass: .regular)
        #expect(input.panelIsOpen)
        #expect(input.focusedLane == .captions)
    }

    @Test func pausesShowOnlyWhilePausesIsOpen() async {
        let viewModel = await makeScenario().viewModel
        viewModel.edit.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 4.1, end: 5), confidence: 1)]
        #expect(viewModel.timelineInput(heightClass: .regular).pauses.isEmpty)
        viewModel.panel = .pauses
        let pauses = viewModel.timelineInput(heightClass: .regular).pauses
        #expect(pauses.count == 1)
        #expect(pauses[0].isMarked)
    }

    // MARK: - Taps

    @Test func tapsPickOrLetGo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.tapTimeline(.clip(clip))
        #expect(viewModel.selection == .clip(clip))
        viewModel.tapTimeline(nil)
        #expect(viewModel.selection == nil)
        viewModel.tapTimeline(.cover)
        #expect(viewModel.panel == .cover)
        viewModel.tapTimeline(.lane(.text))
        #expect(viewModel.toolMenu == .text)
        #expect(viewModel.panel == nil)
        viewModel.tapTimeline(nil)
        #expect(viewModel.toolMenu == nil)
        viewModel.tapTimeline(.addClip)
        #expect(viewModel.sheet == .media)
        #expect(viewModel.mediaInsertMode == .clip)
    }

    @Test func aTrackOpensItsToolsAndASecondTapPutsTheMainOnesBack() async {
        let viewModel = await makeScenario().viewModel
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.toolMenu == .captions)
        #expect(viewModel.timelineInput(heightClass: .regular).activeLanes == [.captions])
        viewModel.tapTimeline(.lane(.captions))
        #expect(viewModel.toolMenu == nil)
        // Music, voice-over and the audio shortcut all open Audio, which lights all three.
        viewModel.tapTimeline(.lane(.voiceOver))
        #expect(viewModel.toolMenu == .audio)
        #expect(viewModel.timelineInput(heightClass: .regular).activeLanes == [.music, .voiceOver, .audio])
        // Another track swaps the tools; a clip lets go of them.
        viewModel.tapTimeline(.lane(.text))
        #expect(viewModel.toolMenu == .text)
        viewModel.tapTimeline(.clip(viewModel.edit.timeline.segments[0].id))
        #expect(viewModel.toolMenu == nil)
    }

    @Test func aClipPanelStaysWhenAnotherClipIsPicked() async {
        let scenario = await makeScenario()
        split(scenario)
        let viewModel = scenario.viewModel
        let segments = viewModel.edit.timeline.segments
        viewModel.tapTimeline(.clip(segments[0].id))
        viewModel.panel = .speed
        viewModel.tapTimeline(.clip(segments[2].id))
        #expect(viewModel.panel == .speed)
        #expect(viewModel.selection == .clip(segments[2].id))
        viewModel.tapTimeline(nil)
        #expect(viewModel.panel == nil)
    }

    @Test func whilePausesIsOpenOnlyPausesAnswer() async {
        let viewModel = await makeScenario().viewModel
        let pause = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 4.1, end: 5), confidence: 1)
        viewModel.edit.suggestions = [pause]
        viewModel.panel = .pauses
        viewModel.tapTimeline(.clip(viewModel.edit.timeline.segments[0].id))
        #expect(viewModel.selection == nil)
        viewModel.tapTimeline(.pause(pause.id))
        #expect(viewModel.timelineInput(heightClass: .regular).pauses.first?.isMarked == false)
        viewModel.tapTimeline(.pause(pause.id))
        #expect(viewModel.timelineInput(heightClass: .regular).pauses.first?.isMarked == true)
    }

    // MARK: - Zoom

    @Test func zoomStaysWithinItsRange() async {
        let viewModel = await makeScenario().viewModel
        viewModel.setTimelineZoom(9)
        #expect(viewModel.timelineZoom == 5)
        viewModel.setTimelineZoom(0.1)
        #expect(viewModel.timelineZoom == 0.35)
        #expect(viewModel.timelineInput(heightClass: .regular).pointsPerSecond == 44 * 0.35)
    }

    // MARK: - Handles

    /// Task 1, by the handles: split before the mistake, then pull the next clip's start past it.
    @Test func aClipsLeftHandleCutsAMistakeAndCompensates() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 7.1)
        viewModel.selectClipAtPlayhead()
        viewModel.splitClip()
        let right = viewModel.edit.timeline.segments[1].id
        scenario.player.seek(to: 2)
        viewModel.beginTimelineHandle(.clip(right, .start), snapTimes: [])
        let result = viewModel.moveTimelineHandle(by: 3)
        #expect(abs(viewModel.edit.timeline.segments[1].sourceStart - 10.1) < 0.000_1)
        #expect(result.label == DurationText.tenths(11.5))
        #expect(abs(result.compensation + 3) < 0.000_1)
        // The preview showed the clip's new first frame while the handle was held.
        #expect(abs(scenario.player.currentTime - 7.1) < 0.000_1)
        viewModel.endTimelineHandle()
        #expect(scenario.player.currentTime == 2)
        #expect(abs(viewModel.edit.editedDuration - 18.6) < 0.000_1)
        // The whole drag is one undo step.
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[1].sourceStart == 7.1)
    }

    @Test func movingAHandleBackBringsTheClipBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.beginTimelineHandle(.clip(clip, .end), snapTimes: [])
        viewModel.moveTimelineHandle(by: -5)
        #expect(abs(viewModel.edit.editedDuration - 16.6) < 0.000_1)
        viewModel.moveTimelineHandle(by: 0)
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.000_1)
        viewModel.endTimelineHandle()
        #expect(!viewModel.canUndo)
    }

    @Test func aHandleSticksToASnapTime() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.beginTimelineHandle(.clip(clip, .end), snapTimes: [15])
        viewModel.moveTimelineHandle(by: -6.55)
        #expect(abs(viewModel.edit.editedDuration - 15) < 0.000_1)
        viewModel.endTimelineHandle()
    }

    @Test func aTextsHandleChangesWhenItEnds() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 1)
        viewModel.addStyledText(.title)
        let id = try #require(viewModel.selectedTextID)
        let span = try #require(viewModel.editedSpan(ofText: id))
        viewModel.beginTimelineHandle(.item(.text, id, .end), snapTimes: [])
        let result = viewModel.moveTimelineHandle(by: 1)
        viewModel.endTimelineHandle()
        let now = try #require(viewModel.editedSpan(ofText: id))
        #expect(abs(now.end - (span.end + 1)) < 0.001)
        #expect(result.label.hasSuffix("s"))
    }

    /// Task 3: the end of a line moves +0.2 s, never into the next line.
    @Test func aCaptionsEndStopsAtTheNextLine() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let line = CaptionCue(text: "e caudo de cana do lado.", start: 14.6, end: 16.2, origin: .manual)
        let next = CaptionCue(text: "Segue pra ver os outros quatro.", start: 17.8, end: 20.6, origin: .manual)
        viewModel.edit.captions = [line, next]
        viewModel.edit.showsCaptions = true
        viewModel.selection = .caption(line.id)
        viewModel.beginTimelineHandle(.item(.caption, line.id, .end), snapTimes: [])
        viewModel.moveTimelineHandle(by: 0.2)
        #expect(abs((viewModel.edit.captions.first { $0.id == line.id }?.end ?? 0) - 16.4) < 0.001)
        viewModel.moveTimelineHandle(by: 5)
        #expect(abs((viewModel.edit.captions.first { $0.id == line.id }?.end ?? 0) - 17.8) < 0.001)
        viewModel.endTimelineHandle()
    }
}
