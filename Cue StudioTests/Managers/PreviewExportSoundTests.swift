//
//  PreviewExportSoundTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// How far the preview's sound is from the exported file's. The preview plays every track through `AVPlayer`'s mix, which gives
/// no way to process the sum, so the export's peak limiter (`Mixdown`) runs only on export. Measured on the rendered files, never a
/// screen recording: a mix that stays under the ceiling sounds the same in both; one that goes over is clipped in the preview where
/// the file is limited, at nearly the same loudness. These are the numbers the decision rests on (matrix 10.3).
@Suite("Preview and export sound", .serialized, .timeLimit(.minutes(2)))
struct PreviewExportSoundTests {
    private struct Level {
        let peak: Float
        let rmsDecibels: Double
        /// Share of samples over full scale: what the preview's output clips.
        let overs: Double
    }

    private func level(of url: URL) throws -> Level {
        let file = try AVAudioFile(forReading: url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16_384))
        var peak: Float = 0, sum = 0.0, count = 0, overs = 0
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for channel in 0..<Int(buffer.format.channelCount) {
                for index in 0..<Int(buffer.frameLength) {
                    let sample = channels[channel][index]
                    peak = max(peak, abs(sample))
                    sum += Double(sample * sample)
                    count += 1
                    if abs(sample) > 1 { overs += 1 }
                }
            }
        }
        let rms = (sum / Double(max(count, 1))).squareRoot()
        return Level(peak: peak, rmsDecibels: 20 * log10(max(rms, 1e-9)), overs: Double(overs) / Double(max(count, 1)))
    }

    /// A voice in syllables (a 220 Hz tone opening and closing four times a second) over music (330 and 495 Hz), mixed as the
    /// export would hear it with the music at `musicVolume`, then through the export's limiter.
    private func mix(voice: Float, music: Float, musicVolume: Float) async throws -> (mixed: Level, exported: Level) {
        let speech = try TestTone.make(seconds: 4) { time in
            let syllable = Float(max(0, sin(2 * .pi * 4 * time)))
            return voice * syllable * Float(sin(2 * .pi * 220 * time))
        }
        let bed = try TestTone.make(seconds: 4) { time in
            music * Float(0.6 * sin(2 * .pi * 330 * time) + 0.4 * sin(2 * .pi * 495 * time))
        }
        defer {
            try? FileManager.default.removeItem(at: speech)
            try? FileManager.default.removeItem(at: bed)
        }
        let composition = AVMutableComposition()
        var sources: [AVURLAsset] = []
        var parameters: [AVMutableAudioMixInputParameters] = []
        for (file, volume) in [(speech, Float(1)), (bed, musicVolume)] {
            let asset = AVURLAsset(url: file)
            sources.append(asset)
            let source = try #require(try await asset.loadTracks(withMediaType: .audio).first)
            let track = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 4, preferredTimescale: 600)), of: source, at: .zero)
            let input = AVMutableAudioMixInputParameters(track: track)
            input.setVolume(volume, at: .zero)
            parameters.append(input)
        }
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = parameters
        let mixed = try await Mixdown.render(composition, tracks: composition.tracks.filter { $0.mediaType == .audio }, audioMix: audioMix)
        defer { try? FileManager.default.removeItem(at: mixed) }
        let limited = try AudioEnhancer.limit(mixed, prefix: "Cue-test-preview-")
        defer { try? FileManager.default.removeItem(at: limited) }
        withExtendedLifetime(sources) {}
        return (try level(of: mixed), try level(of: limited))
    }

    /// Voice and music at everyday levels: what the preview plays is what the file has.
    @Test func aMixUnderTheCeilingSoundsTheSameInThePreviewAndTheFile() async throws {
        let levels = try await mix(voice: 0.5, music: 0.25, musicVolume: 1)
        print("MEASURE preview/export everyday: preview peak \(levels.mixed.peak), file peak \(levels.exported.peak), "
              + "loudness \(levels.mixed.rmsDecibels) → \(levels.exported.rmsDecibels) dB")
        #expect(levels.mixed.peak < AudioCeiling.ceiling)
        #expect(levels.mixed.overs == 0)
        #expect(abs(levels.mixed.rmsDecibels - levels.exported.rmsDecibels) < 0.2)
    }

    /// Loud voice under music at 150%: the preview clips where the file is limited, and the file is nearly as loud, so the
    /// preview never makes the export sound louder than it will be.
    @Test func aMixOverTheCeilingClipsInThePreviewAndIsLimitedInTheFile() async throws {
        let levels = try await mix(voice: 0.8, music: 0.5, musicVolume: 1.5)
        print("MEASURE preview/export loud: preview peak \(levels.mixed.peak) with \(levels.mixed.overs * 100)% clipped samples, "
              + "file peak \(levels.exported.peak), loudness \(levels.mixed.rmsDecibels) → \(levels.exported.rmsDecibels) dB")
        #expect(levels.mixed.overs > 0)
        #expect(levels.exported.peak <= AudioCeiling.ceiling + 0.001)
        #expect(levels.exported.overs == 0)
        #expect(levels.mixed.rmsDecibels - levels.exported.rmsDecibels < 3)
    }
}
