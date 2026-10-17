//
//  CurveSoundRenderer.swift
//  Cue Studio
//

import AVFoundation
import os

/// The sound of a curved clip: played offline through Apple's time-pitch unit ("Keep voice pitch": the voice keeps its tone) or
/// its varispeed (the pitch follows the speed, like tape), the rate following the curve a few milliseconds at a time, so it
/// never drops out or clicks between steps (stretching the sound in steps in the composition does both). Written once into
/// the temporary folder (`Cue-curve-…`, cleaned at the next launch with the other sounds) and reused while the clip doesn't
/// change.
nonisolated enum CurveSoundRenderer {
    /// Frames rendered between two rate changes (5.8 ms at 44.1 kHz).
    static let block: AVAudioFrameCount = 256
    /// The rendered files of this session, by what they render.
    private static let rendered = OSAllocatedUnfairLock(initialState: [String: URL]())

    enum RenderError: Error { case unreadable, cantRender }

    /// The file playing `span` of the sound in `track` along `curve`, as long as the curve makes it.
    static func render(_ track: AVAssetTrack, span: TimeSpan, curve: SpeedCurve, keepsPitch: Bool, key: String) async throws -> URL {
        let name = "Cue-curve-\(stableHash("\(key)|\(span.start)|\(span.end)|\(curve.points)|\(keepsPitch)"))"
        if let ready = rendered.withLock({ $0[name] }), FileManager.default.fileExists(atPath: ready.path(percentEncoded: false)) {
            return ready
        }
        guard let asset = track.asset else { throw RenderError.unreadable }
        let source = try await samples(of: asset, track: track, span: span)
        let url = URL.temporaryDirectory.appending(path: name + ".caf")
        try renderFile(source, curve: curve, length: span.duration, keepsPitch: keepsPitch, to: url)
        rendered.withLock { $0[name] = url }
        return url
    }

    /// The stretch of sound as a buffer, at its own rate and channels (up to two).
    private static func samples(of asset: AVAsset, track: AVAssetTrack, span: TimeSpan) async throws -> AVAudioPCMBuffer {
        let descriptions = try await track.load(.formatDescriptions)
        let basic = descriptions.first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        let rate = basic.map { $0.mSampleRate > 0 ? $0.mSampleRate : 44_100 } ?? 44_100
        let channels = AVAudioChannelCount(min(2, max(1, Int(basic?.mChannelsPerFrame ?? 1))))
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels) else { throw RenderError.unreadable }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: span.start, preferredTimescale: 600), end: CMTime(seconds: span.end, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVNumberOfChannelsKey: channels, AVSampleRateKey: rate,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var interleaved: [Float] = []
        while let ready = try await provider.next() {
            ready.withUnsafeSampleBuffer { sample in
                guard let data = CMSampleBufferGetDataBuffer(sample) else { return }
                let count = CMBlockBufferGetDataLength(data) / MemoryLayout<Float>.size
                let start = interleaved.count
                interleaved.append(contentsOf: repeatElement(0, count: count))
                _ = interleaved.withUnsafeMutableBytes { bytes in
                    CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: count * MemoryLayout<Float>.size, destination: bytes.baseAddress! + start * 4)
                }
            }
        }
        let frames = AVAudioFrameCount(interleaved.count / Int(channels))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let planes = buffer.floatChannelData else {
            throw RenderError.unreadable
        }
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            for channel in 0..<Int(channels) { planes[channel][frame] = interleaved[frame * Int(channels) + channel] }
        }
        return buffer
    }

    /// Plays `source` through the time-pitch unit, offline, its rate set from the curve before each block, until the curve's
    /// length is written (the unit's own delay skipped at the start).
    private static func renderFile(_ source: AVAudioPCMBuffer, curve: SpeedCurve, length: TimeInterval, keepsPitch: Bool, to url: URL) throws {
        let format = source.format
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch(), varispeed = AVAudioUnitVarispeed()
        let pitch: AVAudioUnit = keepsPitch ? timePitch : varispeed
        engine.attach(player)
        engine.attach(pitch)
        try engine.connectNode(player, to: pitch, format: format)
        try engine.connectNode(pitch, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: block)
        try engine.start()
        defer {
            player.stop()
            engine.stop()
        }
        player.scheduleBuffer(source, at: nil)
        try player.playAudio()
        let rate = format.sampleRate
        let wanted = AVAudioFramePosition((curve.editedLength(sourceLength: length) * rate).rounded())
        let delay = AVAudioFramePosition((pitch.latency * rate).rounded())
        guard let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: block) else { throw RenderError.cantRender }
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        var written: AVAudioFramePosition = 0
        var rendered: AVAudioFramePosition = 0
        while written < wanted {
            // The speed where the sound is now: the edited moment of the next frame written.
            let edited = Double(max(0, rendered - delay)) / rate
            let position = curve.sourceOffset(forEdited: edited, sourceLength: length) / max(0.001, length)
            let speed = Float(curve.speed(at: position))
            if keepsPitch { timePitch.rate = speed } else { varispeed.rate = speed }
            let status = try engine.renderOffline(block, to: output)
            guard status == .success else { throw RenderError.cantRender }
            rendered += AVAudioFramePosition(output.frameLength)
            // The unit's delay at the start isn't part of the sound.
            let skip = max(0, delay - (rendered - AVAudioFramePosition(output.frameLength)))
            let keep = min(AVAudioFramePosition(output.frameLength) - min(skip, AVAudioFramePosition(output.frameLength)), wanted - written)
            guard keep > 0 else { continue }
            if skip > 0 || keep < AVAudioFramePosition(output.frameLength) {
                guard let part = AVAudioPCMBuffer(pcmFormat: output.format, frameCapacity: AVAudioFrameCount(keep)),
                      let from = output.floatChannelData, let into = part.floatChannelData else { throw RenderError.cantRender }
                part.frameLength = AVAudioFrameCount(keep)
                let offset = Int(min(skip, AVAudioFramePosition(output.frameLength)))
                for channel in 0..<Int(output.format.channelCount) {
                    into[channel].update(from: from[channel] + offset, count: Int(keep))
                }
                try file.write(from: part)
            } else {
                try file.write(from: output)
            }
            written += keep
        }
    }

    /// A hash that's the same on every launch (Swift's `hashValue` isn't).
    private static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 36)
    }
}
