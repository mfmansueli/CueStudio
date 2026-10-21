//
//  VideoExportFailureTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// An export that can't be made, stops or fails: no half-written file is left behind, and the error that comes out is the
/// one the review tells the creator about (`TakeReviewViewModel.report`).
@MainActor
@Suite("VideoExportService · failures")
struct VideoExportFailureTests {
    private let folder = URL.temporaryDirectory.appending(path: "export-failure-\(UUID().uuidString)", directoryHint: .isDirectory)

    /// `writing`'s work writes half a file, then fails with `error`: what came out of it, and whether the file is still there.
    private func halfWritten(failingWith error: Error) async throws -> (thrown: Error?, fileLeft: Bool) {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let output = folder.appending(path: "Cue-half.mov")
        var thrown: Error?
        do {
            try await VideoExportService.writing(output) {
                try Data(repeating: 1, count: 4096).write(to: output)
                throw error
            }
        } catch {
            thrown = error
        }
        return (thrown, FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
    }

    @Test func iOSInterruptingTheExportLeavesNoFileAndSaysSo() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = try await halfWritten(failingWith: AVError(.operationInterrupted))
        #expect(result.thrown as? VideoExportError == .interrupted)
        #expect(!result.fileLeft)
    }

    @Test func aFailedExportLeavesNoFileAndKeepsItsError() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = try await halfWritten(failingWith: CocoaError(.fileWriteOutOfSpace))
        #expect((result.thrown as? CocoaError)?.code == .fileWriteOutOfSpace)
        #expect(!result.fileLeft)
    }

    /// Cancelled, as when iOS ends the task that carried it outside Cue (`BackgroundExportRunner` says so).
    @Test func aCancelledExportLeavesNoFile() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = try await halfWritten(failingWith: CancellationError())
        #expect(result.thrown is CancellationError)
        #expect(!result.fileLeft)
    }

    @Test func aFinishedExportKeepsItsFile() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let output = folder.appending(path: "Cue-done.mov")
        try await VideoExportService.writing(output) { try Data([0]).write(to: output) }
        #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
    }

    /// A recording with sound and no picture can't become a video: it says so, and nothing is made.
    @Test func aSourceWithoutVideoSaysSo() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try await soundOnlyClip()
        await #expect(throws: VideoExportError.noVideoTrack) {
            _ = try await VideoExportService().export(videoAt: source, options: ExportOptions(aspect: .vertical))
        }
    }

    // MARK: - Helpers

    /// One second of silence in a .mov with no video track.
    private func soundOnlyClip() async throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "sound-only.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: TestClip.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
        ])
        let receiver = writer.inputReceiver(for: input)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        try await TestClip.feedAudio(receiver, frames: 30, loudSeconds: [])
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
}
