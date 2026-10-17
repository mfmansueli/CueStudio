//
//  SoundExtractorTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

extension RealExports {
    /// Extract audio on real files: the stretch of a recording's sound written as an audio file, at the clip's speed, where it
    /// was loud and where it was quiet; a video without sound says so.
    @MainActor
    @Suite("Sound extractor", .serialized, .timeLimit(.minutes(5)))
    struct SoundExtractorTests {
        @Test func theStretchComesOutWhereItWasLoud() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [2])
            defer { try? FileManager.default.removeItem(at: clip) }
            let sound = try await SoundExtractor.write(from: clip, span: TimeSpan(start: 1, end: 4), speed: 1, keepsPitch: true)
            defer { EditMediaFiles.remove([sound.fileName]) }
            let file = EditMediaFiles.url(for: sound.fileName)
            #expect(abs(sound.duration - 3) < 0.000_1)
            #expect(abs(try await AVURLAsset(url: file).load(.duration).seconds - 3) < 0.1)
            #expect(try await AVURLAsset(url: file).loadTracks(withMediaType: .video).isEmpty)
            // Second 2 of the clip is second 1 of the sound.
            #expect(try await TestClip.loudness(of: file, from: 1.2, to: 1.8) > -20)
            #expect(try await TestClip.loudness(of: file, from: 0.1, to: 0.8) < -40)
            #expect(try await TestClip.loudness(of: file, from: 2.2, to: 2.9) < -40)
        }

        @Test func aFasterClipGivesAShorterSoundInStepWithIt() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [2])
            defer { try? FileManager.default.removeItem(at: clip) }
            let sound = try await SoundExtractor.write(from: clip, span: TimeSpan(start: 0, end: 4), speed: 2, keepsPitch: true)
            defer { EditMediaFiles.remove([sound.fileName]) }
            let file = EditMediaFiles.url(for: sound.fileName)
            #expect(abs(sound.duration - 2) < 0.000_1)
            #expect(abs(try await AVURLAsset(url: file).load(.duration).seconds - 2) < 0.1)
            // Second 2 of the clip plays from 1 s to 1.5 s at 2×.
            #expect(try await TestClip.loudness(of: file, from: 1.1, to: 1.4) > -20)
            #expect(try await TestClip.loudness(of: file, from: 0.2, to: 0.8) < -40)
        }

        @Test func aCurvedClipGivesTheSoundAlongItsCurve() async throws {
            let clip = try await TestClip.make(seconds: 4, loudSeconds: [2])
            defer { try? FileManager.default.removeItem(at: clip) }
            // Twice as fast all along, as a curve: like the 2× clip above, rendered along the curve.
            let flat = SpeedCurve(points: [.init(position: 0, speed: 2), .init(position: 1, speed: 2)])
            let sound = try await SoundExtractor.write(from: clip, span: TimeSpan(start: 0, end: 4), speed: 1, keepsPitch: true, curve: flat)
            defer { EditMediaFiles.remove([sound.fileName]) }
            let file = EditMediaFiles.url(for: sound.fileName)
            #expect(abs(sound.duration - 2) < 0.001)
            #expect(abs(try await AVURLAsset(url: file).load(.duration).seconds - 2) < 0.1)
            #expect(try await TestClip.loudness(of: file, from: 1.1, to: 1.4) > -20)
            #expect(try await TestClip.loudness(of: file, from: 0.2, to: 0.8) < -40)
            // Hero: as long as the clip plays.
            let hero = SpeedCurvePreset.hero.curve
            let curved = try await SoundExtractor.write(from: clip, span: TimeSpan(start: 0, end: 4), speed: 1, keepsPitch: false, curve: hero)
            defer { EditMediaFiles.remove([curved.fileName]) }
            let length = hero.editedLength(sourceLength: 4)
            #expect(abs(try await AVURLAsset(url: EditMediaFiles.url(for: curved.fileName)).load(.duration).seconds - length) < 0.1)
        }

        @Test func aVideoWithoutSoundHasNothingToExtract() async throws {
            let clip = try await TestClip.make(seconds: 2)
            defer { try? FileManager.default.removeItem(at: clip) }
            await #expect(throws: AudioTrackExtractor.ExtractError.self) {
                try await SoundExtractor.write(from: clip, span: TimeSpan(start: 0, end: 2), speed: 1, keepsPitch: true)
            }
        }
    }
}
