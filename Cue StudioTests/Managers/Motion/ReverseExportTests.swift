//
//  ReverseExportTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Reverse: the stretch is written backwards, picture and sound, as long as it was, and the montage plays it.
    @MainActor
    @Suite("Reverse export", .serialized, .timeLimit(.minutes(10)))
    struct ReverseExportTests {
        @Test func thePictureRunsBackwards() async throws {
            let path: @Sendable (Int) -> CGPoint = { index in CGPoint(x: 30 + Double(index) * 3, y: 320) }
            let take = try await MovingFootage.make(seconds: 4, width: 360, height: 640, motion: .init(square: path, squareSide: 40))
            defer { try? FileManager.default.removeItem(at: take) }
            let name = try await ReversedClipWriter.write(take, span: TimeSpan(start: 1, end: 3)) { _ in }
            defer { EditMediaFiles.remove([name]) }
            let reversed = EditMediaFiles.url(for: name)
            #expect(abs(try await AVURLAsset(url: reversed).load(.duration).seconds - 2) < 0.07)
            // At 0.2 s it shows the stretch's moment 2.8 s; at 1.8 s, 1.2 s.
            for (time, source) in [(0.2, 2.8), (1.0, 2.0), (1.8, 1.2)] {
                let center = try #require(try await MotionExportTests.squareCenter(in: reversed, at: time), "no square at \(time) s")
                let expected = path(Int((source * 30).rounded())).x / 360
                #expect(abs(center.x - expected) < 8.0 / 360, "at \(time) s: \(center.x * 360) px, expected \(expected * 360) px")
            }
        }

        @Test func theSoundRunsBackwards() async throws {
            // A tone during the second second only.
            let take = try await TestClip.make(seconds: 4, loudSeconds: [1])
            defer { try? FileManager.default.removeItem(at: take) }
            let name = try await ReversedClipWriter.write(take, span: TimeSpan(start: 0.5, end: 3)) { _ in }
            defer { EditMediaFiles.remove([name]) }
            let reversed = EditMediaFiles.url(for: name)
            // Its tone [1, 2] lands on [3 − 2, 3 − 1] = [1, 2] of the reversed file; the silence around it stays silent.
            let inside = try await TestClip.loudness(of: reversed, from: 1.2, to: 1.8)
            let before = try await TestClip.loudness(of: reversed, from: 0.1, to: 0.8)
            let after = try await TestClip.loudness(of: reversed, from: 2.2, to: 2.45)
            #expect(inside > -30 && before < inside - 30 && after < inside - 30, "loudness \(before) · \(inside) · \(after) dB")
        }
    }
}
