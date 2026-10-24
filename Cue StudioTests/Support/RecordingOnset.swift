//
//  RecordingOnset.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation

/// Where the voice begins in a recording: the first 20 ms louder than a tenth of the loudest 20 ms, than −40 dBFS and than the
/// room's own noise by 12 dB (its quietest tenth), that most of the next 100 ms are too, so a click isn't taken for it. People's
/// recordings start with a second or two of room hiss that a single loud sample would take for the voice; the system voices
/// start from silence, where all of these agree. Noise as loud as the voice can't be told from it: the voice then looks
/// longer than it is, never shorter.
enum RecordingOnset {
    private static let window: TimeInterval = 0.02
    private static let floor: Float = 0.01
    /// 12 dB over the room's noise, as an amplitude ratio.
    private static let overNoise: Float = 3.98
    /// Of the five windows from the onset on (100 ms), how many have to be loud.
    private static let sustained = 3

    static func seconds(in samples: [Float], sampleRate: Double) -> TimeInterval {
        span(in: samples, sampleRate: sampleRate).start
    }

    static func seconds(in file: AVAudioFile) -> TimeInterval {
        span(in: file).start
    }

    /// Where the voice begins and where it stops (the same rule read from the end).
    static func span(in file: AVAudioFile) -> (start: TimeInterval, end: TimeInterval) {
        file.framePosition = 0
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil, let channel = buffer.floatChannelData?[0] else { return (0, 0) }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        return span(in: samples, sampleRate: file.processingFormat.sampleRate)
    }

    static func span(in samples: [Float], sampleRate: Double) -> (start: TimeInterval, end: TimeInterval) {
        let frames = max(1, Int(sampleRate * window))
        let levels = stride(from: 0, to: samples.count, by: frames).map { start in
            let slice = samples[start..<min(samples.count, start + frames)]
            return (slice.reduce(0) { $0 + $1 * $1 } / Float(slice.count)).squareRoot()
        }
        let sorted = levels.sorted()
        guard let loudest = sorted.last, loudest > 0 else { return (0, 0) }
        let threshold = max(floor, loudest / 10, sorted[sorted.count / 10] * overNoise)
        let loud = { (window: ArraySlice<Float>) in window.count { $0 > threshold } >= sustained }
        let first = levels.indices.first { levels[$0] > threshold && loud(levels[$0..<min(levels.count, $0 + 5)]) } ?? 0
        let last = levels.indices.last { levels[$0] > threshold && loud(levels[max(0, $0 - 4)...$0]) } ?? levels.count - 1
        let seconds = Double(frames) / sampleRate
        return (Double(first) * seconds, Double(last + 1) * seconds)
    }
}
