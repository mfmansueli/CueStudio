//
//  SampleEditMedia.swift
//  Cue Studio
//

#if DEBUG
import AVFoundation
import Foundation

/// What the editor's demo (`-uiTestDemoEdit`, `SampleEdit.demo`) lays on its take, made at launch into the edit's media
/// (`EditMediaFiles`), since no sound or picture ships with the app: music with a steady beat at 120 BPM (Cue's own sound
/// effects, `SoundEffectSynth`, on every beat), so Beats has something to find; a hummed narration for the voice-over track; and
/// a small B-roll video (`SampleVideo`'s colours). Written once; a file already there is kept. Never shipped.
enum SampleEditMedia {
    static let musicFile = "sample-demo-music.caf"
    static let voiceFile = "sample-demo-voice.caf"
    static let brollFile = "sample-demo-broll.mov"

    static let musicDuration: TimeInterval = 24
    static let voiceDuration: TimeInterval = 4
    static let brollDuration: TimeInterval = 6
    /// The B-roll's width over height (`SampleVideo` writes 144 × 256).
    static let brollAspect = 144.0 / 256.0
    static let tempo: Double = 120

    /// Writes the files that aren't there yet. Blocks: the editor opens right after launch.
    static func writeMissing() {
        try? FileManager.default.createDirectory(at: EditMediaFiles.directory, withIntermediateDirectories: true)
        if !EditMediaFiles.exists(musicFile) { try? writeSound(music(), to: musicFile) }
        if !EditMediaFiles.exists(voiceFile) { try? writeSound(hum(), to: voiceFile) }
        if !EditMediaFiles.exists(brollFile) { SampleVideo.write(to: EditMediaFiles.url(for: brollFile), seconds: brollDuration) }
    }

    // MARK: - Sounds

    private static var sampleRate: Double { SoundEffectSynth.sampleRate }

    /// A pop on every beat and a boom on the first of every four, at `tempo`.
    private static func music() -> [Float] {
        var samples = [Float](repeating: 0, count: Int(musicDuration * sampleRate))
        let pop = SoundEffectSynth.samples(for: .pop)
        let boom = SoundEffectSynth.samples(for: .boom)
        let beatLength = 60 / tempo
        var beat = 0
        while Double(beat) * beatLength < musicDuration {
            let start = Int(Double(beat) * beatLength * sampleRate)
            mix(beat.isMultiple(of: 4) ? boom : pop, into: &samples, at: start, gain: beat.isMultiple(of: 4) ? 0.8 : 0.6)
            beat += 1
        }
        return normalized(samples)
    }

    /// A low voice-like hum that rises and falls about four times a second, like syllables.
    private static func hum() -> [Float] {
        let count = Int(voiceDuration * sampleRate)
        return normalized((0..<count).map { index in
            let time = Double(index) / sampleRate
            let pitch = 165 + 15 * sin(2 * .pi * 0.7 * time)
            let phase = 2 * .pi * pitch * time
            let tone = sin(phase) + 0.5 * sin(2 * phase) + 0.25 * sin(3 * phase)
            let syllables = 0.55 + 0.45 * sin(2 * .pi * 4 * time)
            let edges = min(1, time / 0.1, (voiceDuration - time) / 0.1)
            return Float(tone * syllables * edges)
        })
    }

    private static func mix(_ sound: [Float], into samples: inout [Float], at start: Int, gain: Float) {
        for (offset, value) in sound.enumerated() where start + offset < samples.count {
            samples[start + offset] += value * gain
        }
    }

    /// Peaks at Cue's level for its own sounds (−3 dBFS).
    private static func normalized(_ samples: [Float]) -> [Float] {
        let peak = samples.map(abs).max() ?? 0
        guard peak > 0 else { return samples }
        return samples.map { $0 / peak * SoundEffectSynth.peak }
    }

    /// Mono, 48 kHz, written to a temporary name and moved in once complete.
    private static func writeSound(_ samples: [Float], to name: String) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { throw CocoaError(.fileWriteUnknown) }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (index, value) in samples.enumerated() { channel[index] = value }
        let partial = EditMediaFiles.url(for: "partial-" + name)
        try? FileManager.default.removeItem(at: partial)
        do {
            let file = try AVAudioFile(forWriting: partial, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }
        try FileManager.default.moveItem(at: partial, to: EditMediaFiles.url(for: name))
    }
}
#endif
