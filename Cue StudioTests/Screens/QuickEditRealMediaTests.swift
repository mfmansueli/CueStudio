//
//  QuickEditRealMediaTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Failures the editor wrote down during a test.
@MainActor
private final class RealMediaFailures {
    var reports: [EditorFailureReport] = []
}

/// An editor open on a real recording.
@MainActor
private struct RealMediaEditor {
    let viewModel: QuickEditViewModel
    let takes: TakeLibraryService
    let take: Take
    let clip: URL
    let failures: RealMediaFailures
}

extension RealMedia {
    /// A creator's steps on a real recording: open it, split and undo, freeze a frame, reverse a clip, pull its sound out, leave
    /// a draft and come back, save. After each, the real preview is ready (never failed) and nothing was reported as a failure.
    @MainActor
    @Suite("Quick edit on a real recording", .serialized, .timeLimit(.minutes(5)))
    struct QuickEditRealMediaTests {
        /// The editor on a new 6-second recording, or on `again`'s take (its draft, if one was left).
        private func open(drafts: QuickEditDraftStoring = FakeDraftStore(), again: RealMediaEditor? = nil) async throws -> RealMediaEditor {
            let clip = if let again { again.clip } else { try await TestClip.make(seconds: 6, loudSeconds: [1, 2, 3, 4]) }
            var take = again?.take ?? TestData.take(scriptID: nil, number: 1)
            take.fileName = clip.lastPathComponent
            take.duration = 6
            let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
            takes.load()
            let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
            library.load()
            let editing = TakeEditService(sounds: RecordingSoundCache())
            let viewModel = QuickEditViewModel(
                take: takes.takes[0], takes: takes, library: library, editing: editing, drafts: drafts, toast: ToastService(),
                player: QuickEditPlayer(videoURL: clip, editing: editing, audioSession: FakePlaybackAudioSession()),
                mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
            )
            let failures = RealMediaFailures()
            viewModel.reportFailure = { failures.reports.append($0) }
            await viewModel.prepare()
            try await settle(viewModel)
            return RealMediaEditor(viewModel: viewModel, takes: takes, take: take, clip: clip, failures: failures)
        }

        /// Waits for the real preview to have the edit as it is now: ready, its item ready to play, nothing still building.
        private func settle(_ viewModel: QuickEditViewModel) async throws {
            let player = try #require(viewModel.player as? QuickEditPlayer)
            var steady = 0
            for _ in 0..<400 {
                try #require(player.state != .failed, "The preview couldn't be built")
                let ready = player.state == .ready && !player.isProcessing && player.avPlayer.currentItem?.status == .readyToPlay
                steady = ready ? steady + 1 : 0
                if steady >= 10 { return }
                try await Task.sleep(for: .milliseconds(25))
            }
            Issue.record("The preview never settled")
        }

        private func cleanUp(_ opened: RealMediaEditor) {
            let edit = opened.viewModel.edit
            EditMediaFiles.remove(opened.viewModel.importedFiles.union(edit.mediaFileNames))
            try? FileManager.default.removeItem(at: opened.clip)
        }

        @Test func aRecordingOpensWithItsOwnLengthAndRate() async throws {
            let opened = try await open()
            defer { cleanUp(opened) }
            let viewModel = opened.viewModel
            #expect(viewModel.isReady)
            #expect(abs(viewModel.edit.editedDuration - 6) < 0.05)
            #expect(viewModel.frameRate == 30)
            #expect(opened.failures.reports.isEmpty)
        }

        @Test func aSplitAndItsUndoPlay() async throws {
            let opened = try await open()
            defer { cleanUp(opened) }
            let viewModel = opened.viewModel
            viewModel.player.seek(to: 2)
            viewModel.selectClipAtPlayhead()
            viewModel.splitClip()
            #expect(viewModel.edit.timeline.segments.count == 2)
            try await settle(viewModel)
            viewModel.deleteClip(viewModel.edit.timeline.segments[0].id)
            try await settle(viewModel)
            #expect(abs(viewModel.edit.editedDuration - 4) < 0.05)
            viewModel.undo()
            viewModel.undo()
            try await settle(viewModel)
            #expect(viewModel.edit.timeline.segments.count == 1)
            #expect(opened.failures.reports.isEmpty)
        }

        @Test func aFrozenFrameReverseAndPulledOutSoundPlay() async throws {
            let opened = try await open()
            defer { cleanUp(opened) }
            let viewModel = opened.viewModel
            viewModel.player.seek(to: 2)
            await viewModel.freezeFrame()
            let frozen = try #require(viewModel.edit.sources.first)
            #expect(FileManager.default.fileExists(atPath: EditMediaFiles.url(for: frozen.fileName).path(percentEncoded: false)))
            #expect(viewModel.edit.timeline.segments.count == 3)
            try await settle(viewModel)

            viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
            await viewModel.reverseClip()
            #expect(viewModel.edit.sources.contains { $0.reversal != nil })
            try await settle(viewModel)

            viewModel.selection = .clip(viewModel.edit.timeline.segments[2].id)
            await viewModel.extractAudio()
            let sound = try #require(viewModel.edit.music.first)
            #expect(FileManager.default.fileExists(atPath: EditMediaFiles.url(for: sound.fileName).path(percentEncoded: false)))
            #expect(viewModel.edit.timeline.segments[2].isMuted)
            try await settle(viewModel)
            #expect(opened.failures.reports.isEmpty)
        }

        @Test func aDraftLeftBehindOpensAgainAndDoneSaves() async throws {
            let directory = URL.temporaryDirectory.appending(path: "real drafts \(UUID().uuidString)", directoryHint: .isDirectory)
            defer { try? FileManager.default.removeItem(at: directory) }
            let drafts = QuickEditDraftStore(directory: directory)
            let first = try await open(drafts: drafts)
            first.viewModel.player.seek(to: 2)
            first.viewModel.selectClipAtPlayhead()
            first.viewModel.splitClip()
            first.viewModel.look.pickFilter(.warmFilm)
            first.viewModel.pauseAndKeepDraft()
            let left = first.viewModel.edit

            let again = try await open(drafts: drafts, again: first)
            defer { cleanUp(again) }
            #expect(again.viewModel.edit == left)
            #expect(again.viewModel.canUndo)
            again.viewModel.done()
            #expect(again.takes.takes.first?.edit?.filter == .warmFilm)
            #expect(drafts.draft(for: again.takes.takes[0].id) == nil)
            #expect(first.failures.reports.isEmpty && again.failures.reports.isEmpty)
        }
    }
}
