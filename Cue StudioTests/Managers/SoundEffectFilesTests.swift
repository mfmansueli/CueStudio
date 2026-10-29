//
//  SoundEffectFilesTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Every sound effect has a file: a recording in the bundle or one Cue synthesizes, never both and never neither. The recordings
/// are what the offline export promises (mono, 48 kHz, long enough for the music track, no louder than the synthesized ones,
/// peaks at −3 dBFS at most), and every effect is filed in one group with its words and symbol.
@Suite("Sound effect files")
struct SoundEffectFilesTests {
    private var recorded: [SoundEffect] { SoundEffect.allCases.filter { SoundEffectFiles.bundled($0) != nil } }

    @Test func everyEffectIsRecordedOrSynthesizedNotBoth() {
        let recorded = Set(recorded)
        #expect(recorded.isDisjoint(with: SoundEffectSynth.synthesized))
        #expect(recorded.union(SoundEffectSynth.synthesized) == Set(SoundEffect.allCases))
        #expect(recorded.count == 32, "\(recorded.count) recordings")
    }

    @Test func everyEffectResolvesToAFileThatPlays() throws {
        for effect in SoundEffect.allCases {
            let url = try SoundEffectFiles.file(for: effect)
            let duration = try #require(SoundEffectFiles.duration(ofFile: url), "\(effect)")
            #expect(duration >= Double(MusicClip.minimumDuration) - 0.001, "\(effect): \(duration) s")
        }
    }

    @Test func everyRecordingIsMonoAt48kHzLongEnoughAndNoLouderThanTheRest() throws {
        for effect in recorded {
            let url = try #require(SoundEffectFiles.bundled(effect))
            let file = try AVAudioFile(forReading: url)
            #expect(file.fileFormat.channelCount == 1, "\(effect)")
            #expect(file.fileFormat.sampleRate == 48_000, "\(effect)")
            let samples = try Self.samples(of: file)
            let seconds = Double(samples.count) / 48_000
            #expect(seconds >= 0.5, "\(effect): \(seconds) s")
            let loudness = SoundEffectSynth.loudness(of: samples)
            #expect(loudness <= SoundEffectSynth.targetLoudness + 0.5, "\(effect): \(loudness) LUFS")
            #expect(loudness > -40, "\(effect) is nearly silent: \(loudness) LUFS")
            let peak = samples.map(abs).max() ?? 0
            #expect(peak <= 0.71, "\(effect): peak \(peak)")
        }
    }

    @Test func everyEffectIsInExactlyOneGroupWithItsWordsAndSymbol() {
        let listed = SoundEffectCategory.allCases.flatMap(\.effects)
        #expect(listed.count == SoundEffect.allCases.count)
        #expect(Set(listed) == Set(SoundEffect.allCases))
        for category in SoundEffectCategory.allCases {
            #expect(!category.effects.isEmpty, "\(category)")
            #expect(category.effects.count <= 10, "\(category) has grown unwieldy: \(category.effects.count)")
            #expect(category.effects.allSatisfy { $0.category == category }, "\(category)")
            #expect(category.effects == SoundEffect.effects(in: category), "\(category)")
            #expect(!category.label.isEmpty && UIImage(systemName: category.systemImage) != nil, "\(category)")
        }
        for effect in SoundEffect.allCases {
            #expect(!effect.label.isEmpty && !effect.use.isEmpty, "\(effect)")
            #expect(UIImage(systemName: effect.systemImage) != nil, "\(effect): no symbol \(effect.systemImage)")
        }
        #expect(Set(SoundEffect.allCases.map(\.label)).count == SoundEffect.allCases.count, "no two effects share a name")
    }

    private static func samples(of file: AVAudioFile) throws -> [Float] {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CocoaError(.fileReadUnknown)
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?[0] else { throw CocoaError(.fileReadUnknown) }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
