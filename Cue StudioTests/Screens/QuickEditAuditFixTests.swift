//
//  QuickEditAuditFixTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the editor audit found (2026-10-16), each kept fixed: freeze frame keeps the background and lands where the playhead
/// is, templates leave texts where they were, a tag's word never titles the cover, "Use on every cut" copies the length, Edit by
/// text cuts only the clip the words were read in, and sound effects follow the moment they were put on.
@MainActor
@Suite("Quick edit · audit fixes")
struct QuickEditAuditFixTests {
    private static let said = ["So", "today", "I", "want", "to", "show", "you", "three", "habits"]

    private func makeViewModel(duration: TimeInterval = 30, editor: FakeTakeEditor = FakeTakeEditor()) async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = duration
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        editor.duration = duration
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    @Test func aFrozenFrameKeepsTheBackgroundAndLandsBeforeAClipItOpens() async throws {
        let (viewModel, player) = await makeViewModel()
        var blur = BackgroundEffect()
        blur.style = .blur
        viewModel.change { $0.backgrounds = [RecordingBackground(sourceID: nil, effect: blur)] }
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 10)
        viewModel.commit(timeline)
        let second = viewModel.edit.timeline.segments[1].id
        // Just after the cut: too close to split, so the frame goes before the clip it opens.
        player.seek(to: 10.03)
        await viewModel.clips.freezeFrame()
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 3)
        #expect(segments[1].sourceID == viewModel.edit.sources.first?.id)
        #expect(segments[2].id == second)
        #expect(viewModel.edit.background(for: segments[1])?.style == .blur)
    }

    @Test func aTemplateLeavesTextsWhereTheCreatorPutThem() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.overlays.addText(.callout)
        let id = try #require(viewModel.edit.texts.first?.id)
        viewModel.change { snapshot in
            if let index = snapshot.texts.firstIndex(where: { $0.id == id }) {
                snapshot.texts[index].center = OverlayPoint(x: 0.8, y: 0.3)
                snapshot.texts[index].customized.insert(.position)
            }
        }
        viewModel.applyVideoTemplate(.story)
        let text = try #require(viewModel.edit.texts.first { $0.id == id })
        #expect(text.center == OverlayPoint(x: 0.8, y: 0.3))
        #expect(text.preset == .editorial)
    }

    @Test func aTagsWordNeverTitlesTheCover() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.overlays.addGraphic(.tag)
        #expect(!viewModel.cover.coverSuggestions.contains("NEW"))
    }

    @Test func everyCutGetsTheTransitionAndItsLength() async throws {
        let (viewModel, _) = await makeViewModel()
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 20)
        viewModel.commit(timeline)
        viewModel.selectedJoinID = viewModel.edit.timeline.segments[1].id
        viewModel.clips.setTransition(.zoom)
        viewModel.clips.setTransitionDuration(1.2)
        viewModel.clips.setTransitionOnEveryCut(.zoom)
        #expect(viewModel.edit.timeline.segments.dropFirst().allSatisfy { $0.transitionIn == .zoom && $0.transitionDuration == 1.2 })
        let steps = viewModel.document.history.past.count
        viewModel.clips.setTransitionOnEveryCut(.zoom)
        #expect(viewModel.document.history.past.count == steps)
    }

    @Test func editByTextCutsOnlyTheClipTheWordsWereReadIn() async throws {
        let (viewModel, _) = await makeViewModel(duration: 10)
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        viewModel.updateFindings { $0.captionTranscript = CaptionTranscript(words: words, languageCode: "en") }
        viewModel.change { $0.captions = [CaptionCue(words: words)] }
        viewModel.clips.duplicateSection(viewModel.edit.timeline.segments[0].id)
        #expect(abs(viewModel.edit.editedDuration - 20) < 0.000_1)
        viewModel.clips.tapTranscriptWord(at: 2)
        viewModel.clips.tapTranscriptWord(at: 4)
        viewModel.clips.cutSelectedWords()
        // "I want to" (1.5 s) leaves the first clip; its copy keeps them.
        #expect(abs(viewModel.edit.editedDuration - 18.5) < 0.000_1)
        viewModel.undo()
        #expect(viewModel.clips.transcriptSelection == nil)
    }

    /// A trim drag that goes out past an effect's moment and back leaves the effect exactly where it was: every step of the drag
    /// maps it from the edit before the drag, not from the step before.
    @Test func aSoundEffectComesBackToItsPlaceAfterATrimGoesPastItAndBack() async throws {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 20)
        viewModel.audio.addSoundEffect(.ding)
        let effect = try #require(viewModel.edit.music.first { $0.effect == .ding })
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.beginTimelineHandle(.clip(clip, .end), snapTimes: [])
        viewModel.moveTimelineHandle(by: -15)
        #expect(abs(viewModel.edit.editedDuration - 15) < 0.000_1)
        viewModel.moveTimelineHandle(by: -4)
        viewModel.moveTimelineHandle(by: 0)
        viewModel.endTimelineHandle()
        #expect(abs(viewModel.edit.editedDuration - 30) < 0.000_1)
        let now = try #require(viewModel.edit.music.first { $0.id == effect.id })
        #expect(abs(now.start - effect.start) < 0.000_1)
    }

    @Test func picksInTheTranscriptGoWhenTheCutsChange() async throws {
        let (viewModel, _) = await makeViewModel(duration: 10)
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        viewModel.updateFindings { $0.captionTranscript = CaptionTranscript(words: words, languageCode: "en") }
        viewModel.change { $0.captions = [CaptionCue(words: words)] }
        viewModel.clips.tapTranscriptWord(at: 2)
        viewModel.clips.tapTranscriptWord(at: 4)
        #expect(viewModel.clips.transcriptSelection != nil)
        // A change that leaves the cuts alone keeps the pick.
        viewModel.overlays.addText(.title)
        #expect(viewModel.clips.transcriptSelection != nil)
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 6)
        viewModel.commit(timeline)
        #expect(viewModel.clips.transcriptSelection == nil)
    }

    /// A handle held on something that isn't there leaves no change open: the next change is an undo step of its own.
    @Test func aHandleOnNothingLeavesNoChangeOpen() async throws {
        let (viewModel, _) = await makeViewModel()
        let steps = viewModel.document.history.past.count
        viewModel.beginTimelineHandle(.clip(UUID(), .end), snapTimes: [])
        viewModel.beginTimelineHandle(.move(.text, UUID()), snapTimes: [])
        viewModel.beginTimelineHandle(.item(.caption, UUID(), .start), snapTimes: [])
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 10)
        viewModel.commit(timeline)
        #expect(viewModel.document.history.past.count == steps + 1)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 1)
    }

    @Test func aSoundEffectFollowsItsMomentThroughACut() async throws {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 20)
        viewModel.audio.addSoundEffect(.ding)
        let effect = try #require(viewModel.edit.music.first { $0.effect == .ding })
        #expect(abs(effect.start - 20) < 0.000_1)
        // Five seconds earlier in the video go: the ding plays five seconds earlier, still on its moment.
        var timeline = viewModel.edit.timeline
        timeline.remove([TimeSpan(start: 5, end: 10)])
        viewModel.commit(timeline)
        #expect(abs((viewModel.edit.music.first { $0.id == effect.id }?.start ?? 0) - 15) < 0.000_1)
    }
}
