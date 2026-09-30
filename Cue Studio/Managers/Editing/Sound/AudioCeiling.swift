//
//  AudioCeiling.swift
//  Cue Studio
//

import AVFoundation

/// The loudest a sample may get once mixed: −1 dBFS, which leaves room for the encoder so the
/// exported file never clips. A limiter shapes the peaks first; this checks the result and, when
/// something still goes over, brings the whole file down just enough.
nonisolated enum AudioCeiling {
    /// −1 dBFS.
    static let ceiling: Float = 0.891

    /// The largest sample in the file, 0 to 1 (or more when it clips).
    static func peak(of url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16_384) else { return 0 }
        var peak: Float = 0
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0 else { break }
            peak = max(peak, self.peak(of: buffer))
        }
        return peak
    }

    static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        let layout = layout(of: buffer)
        var peak: Float = 0
        for channel in 0..<layout.pointers {
            for index in 0..<layout.samples { peak = max(peak, abs(channels[channel][index])) }
        }
        return peak
    }

    /// How a buffer's samples are laid out: one pointer per channel, or all channels in one.
    static func layout(of buffer: AVAudioPCMBuffer) -> (pointers: Int, samples: Int) {
        let channels = Int(buffer.format.channelCount), frames = Int(buffer.frameLength)
        return buffer.format.isInterleaved ? (1, frames * channels) : (channels, frames)
    }

    /// The file itself when its peak is under the ceiling; else a copy brought down to it.
    static func keepingUnder(_ url: URL) throws -> URL {
        let peak = try peak(of: url)
        guard peak > ceiling else { return url }
        let scaled = try self.scaled(url, by: ceiling / peak)
        try? FileManager.default.removeItem(at: url)
        return scaled
    }

    /// A copy of the file `gain` times as loud.
    static func scaled(_ url: URL, by gain: Float) throws -> URL {
        let input = try AVAudioFile(forReading: url)
        let format = input.processingFormat
        let outputURL = URL.temporaryDirectory.appending(path: "Cue-level-\(UUID().uuidString.prefix(8)).caf")
        let output = try AVAudioFile(forWriting: outputURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else { throw AudioEnhancer.RenderError.noBuffer }
        while input.framePosition < input.length {
            try input.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            let layout = layout(of: buffer)
            for channel in 0..<layout.pointers {
                for index in 0..<layout.samples { channels[channel][index] *= gain }
            }
            try output.write(from: buffer)
        }
        return outputURL
    }
}
