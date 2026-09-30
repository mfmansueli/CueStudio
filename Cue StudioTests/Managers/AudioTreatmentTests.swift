//
//  AudioTreatmentTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The take's sound treated on the device, on real files: the first treatment still renders for
/// old edits, the levels never push a peak over the ceiling, a loud mix is brought under it, and
/// "Compare with original" measures loudness on speech only.
@Suite("Audio treatment", .serialized, .timeLimit(.minutes(2)))
struct AudioTreatmentTests {
    private func processing(version: Int = 2, volume: Double = 1, enhancement: AudioStrength = .off, noise: AudioStrength = .off) -> VoiceProcessing {
        VoiceProcessing(
            version: version, volume: volume, enhancesVoice: enhancement != .off, reducesNoise: noise != .off,
            enhancement: enhancement, noise: noise
        )
    }

    // MARK: - Loudness

    @Test func speechLoudnessLeavesThePausesOut() throws {
        let level = try #require(SpeechLoudness.level(of: [-20, -20, -80, -80, -80, -80]))
        #expect(abs(level - -20) < 0.01)
        #expect(SpeechLoudness.level(of: [-70, -60]) == nil)
    }

    @Test func aQuieterSoundIsRaisedToMatch() {
        #expect(abs(SpeechLoudness.volume(matching: -26, to: -20) - 2) < 0.01)
        #expect(abs(SpeechLoudness.volume(matching: -20, to: -20) - 1) < 0.001)
    }

    // MARK: - Ceiling

    @Test func aFileOverTheCeilingIsBroughtDownToIt() throws {
        let loud = try TestTone.make(seconds: 1, amplitude: 1)
        defer { try? FileManager.default.removeItem(at: loud) }
        let scaled = try AudioCeiling.keepingUnder(loud)
        defer { try? FileManager.default.removeItem(at: scaled) }
        #expect(abs(try AudioCeiling.peak(of: scaled) - AudioCeiling.ceiling) < 0.01)
    }

    @Test func aFileUnderTheCeilingIsLeftAlone() throws {
        let quiet = try TestTone.make(seconds: 1, amplitude: 0.3)
        defer { try? FileManager.default.removeItem(at: quiet) }
        #expect(try AudioCeiling.keepingUnder(quiet) == quiet)
    }

    // MARK: - Treatments

    @Test func theFirstTreatmentStillRenders() throws {
        let voice = try TestTone.make(seconds: 1.5, amplitude: 0.3)
        defer { try? FileManager.default.removeItem(at: voice) }
        let output = try AudioEnhancer.process(voice, processing: processing(version: 1, enhancement: .soft, noise: .soft))
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(abs(try TestTone.duration(of: output) - 1.5) < 0.01)
        #expect(try AudioCeiling.peak(of: output) > 0.05)
    }

    @Test(arguments: [AudioStrength.soft, .strong])
    func strongerLevelsNeverPushAPeakOverTheCeiling(_ strength: AudioStrength) throws {
        let voice = try TestTone.make(seconds: 1.5, amplitude: 0.85)
        defer { try? FileManager.default.removeItem(at: voice) }
        let output = try AudioEnhancer.process(voice, processing: processing(volume: 1.5, enhancement: strength, noise: strength))
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(abs(try TestTone.duration(of: output) - 1.5) < 0.01)
        #expect(try AudioCeiling.peak(of: output) <= AudioCeiling.ceiling + 0.001)
    }

    @Test func reduceNoiseLowersTheRoomBetweenWords() throws {
        // A voice (−10 dBFS) with a faint hum between words (−50 dBFS).
        let take = try TestTone.make(seconds: 2) { time in
            let voice: Float = time < 1 ? 0.3 * Float(sin(2 * .pi * 440 * time)) : 0
            return voice + 0.003 * Float(sin(2 * .pi * 1000 * time))
        }
        defer { try? FileManager.default.removeItem(at: take) }
        let output = try AudioEnhancer.process(take, processing: processing(noise: .strong))
        defer { try? FileManager.default.removeItem(at: output) }
        let before = try AudioLevelReader.levels(of: take, interval: 0.1)
        let after = try AudioLevelReader.levels(of: output, interval: 0.1)
        // The room (1.3–1.9 s) is quieter; the voice (0.2–0.8 s) stays about as loud.
        #expect(after[15] < before[15] - 3)
        #expect(abs(after[5] - before[5]) < 3)
    }

    @Test func untreatedIsTheSameVolumeWithoutLevels() {
        let treated = processing(volume: 1.2, enhancement: .strong, noise: .soft)
        #expect(treated.untreated.volume == 1.2)
        #expect(treated.untreated.enhancement == .off && treated.untreated.noise == .off)
        #expect(!processing().isNeeded)
        #expect(processing(volume: 0.8).isNeeded)
        #expect(!processing(version: 1).isNeeded)
    }

    // MARK: - Mix

    @Test func twoLoudSoundsMixedTogetherStayUnderTheCeiling() async throws {
        let first = try TestTone.make(seconds: 2, amplitude: 0.8)
        let second = try TestTone.make(seconds: 2, amplitude: 0.8)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        let composition = AVMutableComposition()
        for file in [first, second] {
            // Kept alive: a track can't be inserted once its asset is gone.
            let asset = AVURLAsset(url: file)
            let source = try #require(try await asset.loadTracks(withMediaType: .audio).first)
            let track = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)), of: source, at: .zero)
            withExtendedLifetime(asset) {}
        }
        let tracks = composition.tracks.filter { $0.mediaType == .audio }
        let mixed = try await MasterMix.render(composition, tracks: tracks, audioMix: nil)
        defer { try? FileManager.default.removeItem(at: mixed) }
        // Together they'd reach 1.6.
        #expect(try AudioCeiling.peak(of: mixed) > 1)
        let limited = try AudioEnhancer.limit(mixed)
        defer { try? FileManager.default.removeItem(at: limited) }
        #expect(try AudioCeiling.peak(of: limited) <= AudioCeiling.ceiling + 0.001)
        #expect(abs(try TestTone.duration(of: limited) - 2) < 0.02)
    }
}
