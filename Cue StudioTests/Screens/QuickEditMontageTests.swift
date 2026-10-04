//
//  QuickEditMontageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Montage in Quick edit: copies carry what plays on them, a new order takes texts along, other
/// takes join by linking their file, captions come from each recording, and photos and videos
/// overlap up to three at a time in the order they stack.
@MainActor
@Suite("Quick edit montage")
struct QuickEditMontageTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let toast: ToastService
        let other: Take
    }

    private func makeScenario(editor: FakeTakeEditor = FakeTakeEditor()) async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let other = TestData.take(scriptID: nil, title: "B-roll walk", number: 1)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take, other]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes.first { $0.id == take.id } ?? takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor, player: player, toast: toast, other: other)
    }

    private func photo() -> ImportedMedia {
        ImportedMedia(kind: .photo, fileName: "photo-\(UUID().uuidString).jpg", aspect: 1, duration: nil)
    }

    /// A file where the library keeps `take`'s video, so it can be linked.
    private func writeVideo(of take: Take, in viewModel: QuickEditViewModel) throws -> URL {
        let url = viewModel.takes.videoURL(for: take)
        try Data("video".utf8).write(to: url)
        return url
    }

    // MARK: - Copies and order

    @Test func aCopiedSectionGetsItsOwnTextsInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 32
        viewModel.cut()
        scenario.player.currentTime = 5
        viewModel.addText(.title)
        let steps = viewModel.history.past.count
        viewModel.tapTimeline(onPiece: 0)
        viewModel.duplicateSection()
        #expect(viewModel.history.past.count == steps + 1)
        #expect(viewModel.edit.timeline.segments.count == 3)
        #expect(viewModel.edit.texts.count == 2)
        let ids = Set(viewModel.edit.texts.map(\.id))
        #expect(ids.count == 2)
        // Each on its own section: at 5 s, and at 5 s into the copy.
        let spans = viewModel.textBars.map(\.span.start).sorted()
        let copyStart = viewModel.edit.timeline.editedStart(ofSegmentAt: 1)
        #expect(spans == [5, copyStart + 5])
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 2)
        #expect(viewModel.edit.texts.count == 1)
    }

    @Test func aMovedSectionTakesItsTextAlong() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 32
        viewModel.cut()
        scenario.player.currentTime = 40
        viewModel.addText(.hook)
        viewModel.moveSection(from: 1, to: 0)
        // The section that started at 32 s now starts the edit: the text is 8 s in.
        #expect(abs((viewModel.textBars.first?.span.start ?? 0) - 8) < 0.001)
        #expect(viewModel.edit.timeline.isArranged)
    }

    // MARK: - Other takes

    @Test func anotherTakeJoinsByLinkingItsFileAndLeavesWithoutDeletingIt() async throws {
        let editor = FakeTakeEditor()
        editor.duration = 12
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        let original = try writeVideo(of: scenario.other, in: viewModel)
        defer { try? FileManager.default.removeItem(at: original) }
        await viewModel.addClip(from: scenario.other)
        let source = try #require(viewModel.edit.sources.first)
        defer { EditMediaFiles.remove([source.fileName]) }
        #expect(source.takeID == scenario.other.id)
        #expect(EditMediaFiles.exists(source.fileName))
        #expect(viewModel.edit.timeline.segments.last?.sourceID == source.id)
        #expect(viewModel.edit.mediaFileNames.contains(source.fileName))
        #expect(viewModel.clips.last?.title == "B-roll walk · Take 1")

        let section = try #require(viewModel.edit.timeline.segments.last?.id)
        viewModel.removeSection(section)
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(FileManager.default.fileExists(atPath: original.path(percentEncoded: false)))
    }

    @Test func captionsListenToEveryRecordingTheMontagePlays() async throws {
        let editor = FakeTakeEditor()
        editor.duration = 12
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        let original = try writeVideo(of: scenario.other, in: viewModel)
        defer { try? FileManager.default.removeItem(at: original) }
        await viewModel.addClip(from: scenario.other)
        let source = try #require(viewModel.edit.sources.first)
        defer { EditMediaFiles.remove([source.fileName]) }
        viewModel.makeCaptions()
        await viewModel.captionTask?.value
        #expect(editor.captionRequests == 2)
        #expect(Set(viewModel.edit.captions.map(\.sourceID)) == [nil, source.id])
        #expect(viewModel.edit.sourceTranscripts.first?.sourceID == source.id)
        // Each recording's line shows where that recording plays.
        #expect(viewModel.edit.editedCaptions.count == 2)
    }

    @Test func aCopiedSectionShowsItsCaptionsAgain() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await viewModel.captionTask?.value
        viewModel.duplicateSection(viewModel.edit.timeline.segments[0].id)
        let instances = viewModel.edit.editedCaptionInstances
        #expect(instances.count == 2)
        #expect(Set(instances.map(\.line.id)).count == 2)
        #expect(Set(instances.map(\.cueID)) == [viewModel.edit.captions[0].id])
        // Picking the copy's line picks the line both show.
        viewModel.selectBar(viewModel.captionBars[1])
        #expect(viewModel.selectedCaptionID == viewModel.edit.captions[0].id)
    }

    // MARK: - Overlays

    @Test func upToThreePhotosOrVideosShowAtOnce() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        for _ in 0..<3 { viewModel.addMedia(photo()) }
        #expect(viewModel.edit.media.count == 3)
        #expect(viewModel.edit.media.map(\.stackOrder) == [0, 1, 2])
        viewModel.addMedia(photo())
        #expect(viewModel.edit.media.count == 3)
        #expect(scenario.toast.message == "Max 3 photos or videos")
    }

    @Test func thePickedOneMovesUpOrDownTheStack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addMedia(photo())
        viewModel.addMedia(photo())
        let bottom = viewModel.edit.media[0].id
        #expect(!viewModel.canRestack(bottom, up: false))
        viewModel.restack(bottom, up: true)
        #expect(viewModel.edit.media.first { $0.id == bottom }?.stackOrder == 1)
        viewModel.undo()
        #expect(viewModel.edit.media.first { $0.id == bottom }?.stackOrder == 0)
    }

    @Test func overlapCountsTheBusiestMoment() {
        let spans = [TimeSpan(start: 0, end: 4), TimeSpan(start: 2, end: 6), TimeSpan(start: 5, end: 9)]
        #expect(LayerLanes.peak(of: spans, within: TimeSpan(start: 0, end: 10)) == 2)
        #expect(LayerLanes.peak(of: spans, within: TimeSpan(start: 6.5, end: 8)) == 1)
    }
}
