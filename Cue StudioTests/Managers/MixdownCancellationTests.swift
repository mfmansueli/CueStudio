//
//  MixdownCancellationTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The mix an export makes of more than the take's sound hears a cancel: rendering the mix, the limiter and bringing it under the
/// ceiling each stop at once, and leave no half-written file in the temporary folder.
@Suite("Mixdown cancellation", .serialized, .timeLimit(.minutes(2)))
struct MixdownCancellationTests {
    /// Runs `work` in a task that is already cancelled.
    private func cancelled<Value: Sendable>(_ work: @escaping @Sendable () async throws -> Value) async -> Error? {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await work()
        }
        do {
            _ = try await task.value
            return nil
        } catch {
            return error
        }
    }

    private func files(prefixed prefix: String) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: URL.temporaryDirectory.path(percentEncoded: false))) ?? []
        return Set(names.filter { $0.hasPrefix(prefix) })
    }

    @Test func aCancelledMixStopsAndLeavesNoFile() async throws {
        let first = try TestTone.make(seconds: 3, amplitude: 0.4)
        let second = try TestTone.make(seconds: 3, amplitude: 0.4)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let before = files(prefixed: "Cue-master-")
        let task = Task {
            let composition = AVMutableComposition()
            var sources: [AVURLAsset] = []
            for file in [first, second] {
                let asset = AVURLAsset(url: file)
                sources.append(asset)
                let source = try #require(try await asset.loadTracks(withMediaType: .audio).first)
                let track = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
                try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)), of: source, at: .zero)
            }
            // Cancelled with the mix ready to render.
            withUnsafeCurrentTask { $0?.cancel() }
            defer { withExtendedLifetime(sources) {} }
            return try await Mixdown.render(composition, tracks: composition.tracks.filter { $0.mediaType == .audio }, audioMix: nil)
        }
        var thrown: Error?
        do { _ = try await task.value } catch { thrown = error }
        #expect(thrown is CancellationError)
        #expect(files(prefixed: "Cue-master-").subtracting(before).isEmpty)
    }

    @Test func aCancelledLimiterStopsAndLeavesNoFile() async throws {
        let mix = try TestTone.make(seconds: 3, amplitude: 0.9)
        defer { try? FileManager.default.removeItem(at: mix) }
        let before = files(prefixed: Mixdown.filePrefix)
        let error = await cancelled { try AudioEnhancer.limit(mix, prefix: Mixdown.filePrefix) }
        #expect(error is CancellationError)
        #expect(files(prefixed: Mixdown.filePrefix).subtracting(before).isEmpty)
    }

    @Test func bringingAMixUnderTheCeilingHearsACancelToo() async throws {
        let loud = try TestTone.make(seconds: 3, amplitude: 1.4)
        defer { try? FileManager.default.removeItem(at: loud) }
        let before = files(prefixed: "Cue-level-")
        let error = await cancelled { try AudioCeiling.keepingUnder(loud) }
        #expect(error is CancellationError)
        #expect(files(prefixed: "Cue-level-").subtracting(before).isEmpty)
        // The file it was asked to bring down is the caller's: still there.
        #expect(FileManager.default.fileExists(atPath: loud.path(percentEncoded: false)))
    }

    /// Not cancelled, the limiter still makes its file (what an export plays).
    @Test func theLimiterStillWorksWhenNothingCancels() throws {
        let mix = try TestTone.make(seconds: 1, amplitude: 0.9)
        defer { try? FileManager.default.removeItem(at: mix) }
        let limited = try AudioEnhancer.limit(mix, prefix: Mixdown.filePrefix)
        defer { try? FileManager.default.removeItem(at: limited) }
        #expect(limited.lastPathComponent.hasPrefix(Mixdown.filePrefix) || limited.lastPathComponent.hasPrefix("Cue-level-"))
        #expect(try AudioCeiling.peak(of: limited) <= AudioCeiling.ceiling + 0.001)
    }
}
