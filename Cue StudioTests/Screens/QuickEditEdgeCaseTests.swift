//
//  QuickEditEdgeCaseTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor at its limits: a 1 s take and a 5 min one, every caption deleted, a text with
/// keyframes whose part is cut, and the timeline's zoom at both ends.
@MainActor
@Suite("Quick edit edge cases")
struct QuickEditEdgeCaseTests {
    private func makeViewModel(seconds: TimeInterval) async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = seconds
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = seconds
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    @Test func aOneSecondTakeSplitsAndKeepsAClip() async {
        let (viewModel, player) = await makeViewModel(seconds: 1)
        player.seek(to: 0.5)
        viewModel.selectClipAtPlayhead()
        viewModel.splitClip()
        #expect(viewModel.edit.timeline.segments.count == 2)
        let first = viewModel.edit.timeline.segments[0].id
        viewModel.deleteClip(first)
        #expect(viewModel.edit.timeline.segments.count == 1)
        // The last clip can't go.
        viewModel.deleteClip(viewModel.edit.timeline.segments[0].id)
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(abs(viewModel.edit.editedDuration - 0.5) < 0.001)
        let geometry = TimelineGeometry(viewModel.timelineInput(heightClass: .veryCompact))
        #expect(geometry.clips.count == 1)
        #expect(geometry.contentWidth > 0)
    }

    @Test func aFiveMinuteTakeLaysOutAndScrubsToTheEnd() async {
        let (viewModel, player) = await makeViewModel(seconds: 300)
        let geometry = TimelineGeometry(viewModel.timelineInput(heightClass: .regular))
        #expect(abs(geometry.contentWidth - 300 * TimelineGeometry.basePointsPerSecond) < 0.5)
        viewModel.scrub(to: 299.9)
        #expect(abs(player.currentTime - 299.9) < 0.001)
        // The ruler keeps a readable step all the way out.
        let ticks = TimelineRuler.ticks(from: 0, to: 300, duration: 300, pointsPerSecond: geometry.pointsPerSecond * 0.35)
        #expect(!ticks.isEmpty)
        #expect(ticks.count < 400)
    }

    @Test func deletingEveryCaptionLeavesAnEmptyListThatCanBeRemade() async {
        let (viewModel, _) = await makeViewModel(seconds: 20)
        viewModel.edit.captions = [
            CaptionCue(text: "One", start: 0, end: 2), CaptionCue(text: "Two", start: 2, end: 4),
        ]
        viewModel.edit.showsCaptions = true
        for line in viewModel.captionListLines { viewModel.deleteCaptionLine(line.cueID) }
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.captionListLines.isEmpty)
        #expect(viewModel.panelSubtitle(.captions) == "0 lines · tap one to jump there")
        // Captions now open on Auto captions.
        viewModel.openCaptions()
        #expect(viewModel.panel == .autoCaptions)
        let geometry = TimelineGeometry(viewModel.timelineInput(heightClass: .regular))
        #expect(geometry.ghosts.contains { $0.target == .captions && $0.label == "Auto captions" })
        viewModel.undo()
        #expect(viewModel.edit.captions.count == 1)
    }

    @Test func cuttingATextWithKeyframesHidesItAndUndoBringsItBack() async {
        let (viewModel, player) = await makeViewModel(seconds: 20)
        player.seek(to: 5)
        viewModel.addStyledText(.title)
        let id = viewModel.edit.texts[0].id
        viewModel.toggleKeyframe()
        player.seek(to: 7)
        viewModel.toggleKeyframe()
        #expect(viewModel.edit.texts[0].keyframes.count == 2)
        // Seconds 4 to 9 go: the whole text with them.
        var timeline = viewModel.edit.timeline
        _ = timeline.removeEdited(4...9)
        viewModel.commit(timeline)
        #expect(viewModel.editedSpan(ofText: id) == nil)
        #expect(viewModel.edit.texts.count == 1)
        #expect(!viewModel.textBars.contains { $0.id == id })
        viewModel.undo()
        #expect(viewModel.editedSpan(ofText: id) != nil)
        #expect(viewModel.edit.texts[0].keyframes.count == 2)
    }

    @Test func theZoomStopsAtBothEnds() async {
        let (viewModel, _) = await makeViewModel(seconds: 20)
        viewModel.setTimelineZoom(100)
        #expect(viewModel.timelineZoom == TimelineGeometry.zoomRange.upperBound)
        let near = TimelineGeometry(viewModel.timelineInput(heightClass: .regular))
        #expect(abs(near.pointsPerSecond - 44 * 5) < 0.001)
        viewModel.setTimelineZoom(0)
        #expect(viewModel.timelineZoom == TimelineGeometry.zoomRange.lowerBound)
        let far = TimelineGeometry(viewModel.timelineInput(heightClass: .regular))
        #expect(abs(far.pointsPerSecond - 44 * 0.35) < 0.001)
    }
}
