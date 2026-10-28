//
//  QuickEditPanelPreviewTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// ▶ PREVIEW in a panel's header (`PanelPlay`): it shows only when the panel has something that plays, and plays that part
/// of the video once: a text's or a photo's way in (its Motion, or a text's effect), the clip's zoom or speed, across the
/// picked cut.
@MainActor
@Suite("Quick edit · panel preview")
struct QuickEditPanelPreviewTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player)
    }

    private func addTitle(_ scenario: Scenario, at time: TimeInterval) throws -> TimeSpan {
        scenario.player.seek(to: time)
        scenario.viewModel.overlays.addStyledText(.title)
        let id = try #require(scenario.viewModel.selectedTextID)
        scenario.viewModel.overlays.setTextContent(id, "ola tudo bem")
        scenario.viewModel.overlays.endAllChanges()
        return try #require(scenario.viewModel.overlays.editedSpan(ofText: id))
    }

    @Test func aTextPlaysItsWayInOnlyWhenSomethingMovesIt() async throws {
        let scenario = await makeScenario()
        let overlays = scenario.viewModel.overlays
        let span = try addTitle(scenario, at: 10)
        #expect(!overlays.canPreviewMotion)
        overlays.setMotionPreset(.fade)
        #expect(overlays.canPreviewMotion)
        scenario.player.seek(to: span.start + 1)
        overlays.previewMotion()
        // A Motion: as long as it takes and a little more to see where it lands.
        #expect(scenario.player.reviewedPart == span.start...(span.start + 1.25))
        #expect(scenario.player.isPlaying)
    }

    @Test func aTextsEffectPlaysAsLongAsItsWayIn() async throws {
        let scenario = await makeScenario()
        let overlays = scenario.viewModel.overlays
        let span = try addTitle(scenario, at: 10)
        overlays.pickTextPreset(.wave)
        #expect(overlays.canPreviewMotion)
        let effect = try #require(overlays.selectedText?.effect)
        overlays.previewMotion()
        #expect(scenario.player.reviewedPart == span.start...(span.start + effect.duration + 0.9))
        // Still, with no Motion: nothing moves it in.
        overlays.restyleText(.effectMotion(.still))
        #expect(!overlays.canPreviewMotion)
    }

    @Test func aClipsSpeedPlaysOnlyOffNormal() async throws {
        let scenario = await makeScenario()
        let clips = scenario.viewModel.clips
        scenario.player.seek(to: 32)
        clips.splitClip()
        scenario.player.seek(to: 40)
        #expect(!clips.canPreviewSpeed)
        clips.setClipSpeed(2)
        #expect(clips.canPreviewSpeed)
        clips.previewSpeed()
        #expect(scenario.player.reviewedPart == 32...38)
    }

    @Test func aZoomPlaysTheClipsStartAgain() async throws {
        let scenario = await makeScenario()
        let clips = scenario.viewModel.clips
        scenario.player.seek(to: 32)
        clips.splitClip()
        scenario.player.seek(to: 40)
        clips.setClipZoom(.pushIn)
        scenario.player.reviewedPart = nil
        clips.previewZoom()
        #expect(scenario.player.reviewedPart == 32...(32 + ClipsViewModel.zoomPreviewLength))
    }

    @Test func aTransitionPlaysAcrossItsCut() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 32)
        viewModel.clips.splitClip()
        viewModel.pickJoin(viewModel.edit.timeline.segments[1].id)
        #expect(viewModel.clips.selectedTransitionDuration == nil)
        viewModel.clips.setTransition(.dissolve)
        let duration = try #require(viewModel.clips.selectedTransitionDuration)
        viewModel.clips.previewTransition()
        let lead = ClipsViewModel.transitionLeadIn
        #expect(scenario.player.reviewedPart == (32 - lead)...(32 + duration + lead))
    }

    // MARK: - The playhead taken during a preview

    /// The ways a creator takes the playhead.
    enum Taking: CaseIterable, Sendable {
        case play, scrub, frameStep, jumpToCut, nudge, handle
    }

    /// A title with a Motion at 10 s, its way in playing (`previewMotion`) from a playhead at 4 s.
    private func previewingATitle() async throws -> Scenario {
        let scenario = await makeScenario()
        _ = try addTitle(scenario, at: 10)
        scenario.viewModel.overlays.setMotionPreset(.fade)
        scenario.player.seek(to: 4)
        scenario.viewModel.overlays.previewMotion()
        #expect(scenario.player.reviewedPart != nil)
        return scenario
    }

    @Test func aPreviewLeftAloneGoesBackToWhereItBegan() async throws {
        let scenario = try await previewingATitle()
        await scenario.viewModel.session.jobs.finished(.preview)
        #expect(!scenario.player.isPlaying)
        #expect(scenario.player.currentTime == 4)
        #expect(scenario.player.reviewedPart == nil)
    }

    /// The case a creator met: Preview, then the playhead dragged elsewhere and Play before the preview's time was up. Play
    /// runs on from there; the preview never pauses it nor pulls it back (waited for longer than it lasts: a slow Mac can only
    /// hide a preview that comes back, never fail this).
    @Test func aPlayheadTakenDuringAPreviewIsNeverPulledBack() async throws {
        let scenario = try await previewingATitle()
        let viewModel = scenario.viewModel
        viewModel.closePanel()
        viewModel.scrubTimeline(to: 20)
        viewModel.endTimelineScrub()
        viewModel.togglePlayback()
        try await Task.sleep(for: .seconds(1.25 + 0.6))
        #expect(scenario.player.isPlaying)
        #expect(scenario.player.currentTime == 20)
        #expect(scenario.player.reviewedPart == nil)
    }

    @Test(arguments: Taking.allCases)
    func everyWayOfTakingThePlayheadEndsThePreview(_ taking: Taking) async throws {
        let scenario = try await previewingATitle()
        let viewModel = scenario.viewModel
        switch taking {
        case .play: viewModel.togglePlayback()
        case .scrub: viewModel.scrubTimeline(to: 20)
        case .frameStep: viewModel.stepFrame(1)
        case .jumpToCut: viewModel.jumpToCut(forward: true)
        case .nudge: viewModel.nudgePlayhead(by: 1)
        case .handle:
            viewModel.beginTimelineHandle(.clip(viewModel.edit.timeline.segments[0].id, .end), snapTimes: [])
            viewModel.endTimelineHandle()
        }
        #expect(!viewModel.session.jobs.isRunning(.preview))
        #expect(scenario.player.reviewedPart == nil)
    }
}
