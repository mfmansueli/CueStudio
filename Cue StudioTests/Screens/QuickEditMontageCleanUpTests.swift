//
//  QuickEditMontageCleanUpTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Clean Up over a montage: every recording it plays is listened to once, each suggestion stays with its recording, and
/// removing one cuts that recording wherever it plays (in each copy, at its speed), never the take at the same second.
@MainActor
@Suite("Quick edit Clean Up in a montage")
struct QuickEditMontageCleanUpTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let source: ClipSource
        let cleanUp: () -> Void
    }

    /// The take (12 s) then another take (12 s); both have a pause from 10 to 12 s.
    private func makeScenario() async throws -> Scenario {
        let editor = FakeTakeEditor()
        editor.duration = 12
        editor.silences = [TimeSpan(start: 10, end: 12)]
        let take = TestData.take(scriptID: nil, number: 3)
        let other = TestData.take(scriptID: nil, title: "Interview", number: 2)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take, other]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes.first { $0.id == take.id } ?? takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let file = viewModel.takes.videoURL(for: other)
        try Data("video".utf8).write(to: file)
        await viewModel.addClip(from: other)
        let source = try #require(viewModel.edit.sources.first)
        return Scenario(viewModel: viewModel, editor: editor, source: source) {
            try? FileManager.default.removeItem(at: file)
            EditMediaFiles.remove([source.fileName])
        }
    }

    /// Pauses with only `id` marked to go, then "Remove": what the creator does to take out one pause.
    private func removeOnly(_ id: UUID, in viewModel: QuickEditViewModel) {
        viewModel.panel = .pauses
        for other in viewModel.pauseCandidates + viewModel.wordCandidates where other.id != id && viewModel.isMarked(other) {
            viewModel.toggleMark(other.id)
        }
        viewModel.applyCleanUp()
    }

    @Test func everyRecordingIsListenedToAndKeepsItsSuggestions() async throws {
        let scenario = try await makeScenario()
        defer { scenario.cleanUp() }
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        #expect(scenario.editor.cleanUpVideos.count == 2)
        let pauses = viewModel.pauseCandidates
        #expect(Set(pauses.map(\.sourceID)) == [nil, scenario.source.id])
        // In the order they play: the take's at 10 s, the other take's at 22 s.
        #expect(pauses.compactMap { viewModel.edit.timeline.editedSpan(of: $0)?.start } == [10, 22])
        #expect(viewModel.cardTime(pauses[1]).hasPrefix("Interview · "))
        // Opening it again listens to nothing new.
        await viewModel.analyzeIfNeeded()
        #expect(scenario.editor.cleanUpVideos.count == 2)
    }

    @Test func removingTheOtherTakesPauseCutsOnlyThatTake() async throws {
        let scenario = try await makeScenario()
        defer { scenario.cleanUp() }
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        let theirs = try #require(viewModel.pauseCandidates.first { $0.sourceID == scenario.source.id })
        removeOnly(theirs.id, in: viewModel)
        let timeline = viewModel.edit.timeline
        // The take plays whole; the other take loses its pause (the cut keeps a breath on both sides).
        #expect(timeline.segments.filter { $0.sourceID == nil }.map(\.span) == [TimeSpan(start: 0, end: 12)])
        #expect(timeline.isRemoved(theirs))
        #expect(!timeline.isRemoved(try #require(viewModel.pauseCandidates.first { $0.sourceID == nil })))
        viewModel.undo()
        #expect(!viewModel.edit.timeline.isRemoved(theirs))
    }

    @Test func aNewOrderACopyAndASpeedMoveWhereItPlays() async throws {
        let scenario = try await makeScenario()
        defer { scenario.cleanUp() }
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        let theirs = try #require(viewModel.pauseCandidates.first { $0.sourceID == scenario.source.id })
        viewModel.moveSection(from: 1, to: 0)
        #expect(viewModel.edit.timeline.editedSpan(of: theirs)?.start == 10)
        viewModel.duplicateSection(viewModel.edit.timeline.segments[0].id)
        var faster = viewModel.edit.timeline
        faster.setSpeed(2, forSegmentAt: 0)
        viewModel.commit(faster)
        // At 2× the 2 s pause lasts 1 s; the copy still plays it at 1×.
        #expect(viewModel.edit.timeline.editedSpan(of: theirs)?.duration == 1)
        // Removing it takes it out of the original and the copy alike.
        removeOnly(theirs.id, in: viewModel)
        let pieces = viewModel.edit.timeline.segments.filter { $0.sourceID == scenario.source.id }
        #expect(pieces.allSatisfy { !$0.span.overlaps(TimeSpan(start: 10.2, end: 11.8)) })
    }

    @Test func aRecordingThatCantBeHeardLeavesTheOthersSuggestions() async throws {
        let scenario = try await makeScenario()
        defer { scenario.cleanUp() }
        scenario.editor.cleanUpFailsFor = EditMediaFiles.url(for: scenario.source.fileName)
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        #expect(viewModel.analysis == .done)
        #expect(viewModel.pauseCandidates.map(\.sourceID) == [nil])
        // It's tried again next time.
        scenario.editor.cleanUpFailsFor = nil
        await viewModel.analyzeIfNeeded()
        #expect(Set(viewModel.pauseCandidates.map(\.sourceID)) == [nil, scenario.source.id])
    }

    @Test func suggestionsSavedBeforeMontagesAreTheTakes() throws {
        let json = #"{"id":"6B1C9B0E-3B1F-4C8B-9E4C-3B2B0C7E0A11","kind":"pause","span":{"start":1,"end":2},"confidence":1}"#
        let suggestion = try JSONDecoder().decode(CleanUpSuggestion.self, from: Data(json.utf8))
        #expect(suggestion.sourceID == nil)
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.cleanUpAnalyzed = true
        #expect(edit.recordingsToCleanUp.isEmpty)
    }
}
