//
//  CurveSoundRenderer.swift
//  Cue Studio
//

import AVFoundation
import os

/// The sound of a curved clip: played offline through Apple's time-pitch unit ("Keep voice pitch": the voice keeps its tone) or
/// its varispeed (the pitch follows the speed, like tape), the rate following the curve a few milliseconds at a time, so it
/// never drops out or clicks between steps (stretching the sound in steps in the composition does both). Off the main thread,
/// stopped as soon as the build that wants it is dropped, and streamed: the recording is read a second at a time and only a
/// few seconds of it are ever held, whatever the clip's length. Written once into the temporary folder (`Cue-curve-…`,
/// cleaned at the next launch with the other sounds) and reused while the clip doesn't change; a clip's older renders are
/// removed as new ones replace them.
nonisolated enum CurveSoundRenderer {
    /// Frames rendered between two rate changes (5.8 ms at 44.1 kHz).
    static let block: AVAudioFrameCount = 256
    /// Seconds of the recording read and handed to the player at a time.
    static let chunkSeconds = 1.0
    /// Seconds of the recording kept queued ahead of what the player has played.
    static let aheadSeconds = 2.0
    /// Renders kept per clip: the newest, and the one before it (the preview may still be playing it while the new item is built).
    static let keptPerClip = 2

    /// The rendered files of this session, by what they render, and the names each clip used, oldest first.
    private struct Rendered {
        var files: [String: URL] = [:]
        var byClip: [String: [String]] = [:]
    }

    private static let rendered = OSAllocatedUnfairLock(initialState: Rendered())

    enum RenderError: Error { case unreadable, cantRender }

    /// The file playing `span` of the sound track `trackID` of `file` (a recording, or Studio Voice's treatment of it: a new
    /// treatment is a new file) along `curve`, as long as the curve makes it. `clip` names the clip it's for, whose older
    /// renders go once replaced. Throws `CancellationError` when the task is cancelled.
    @concurrent
    static func render(
        file: URL, trackID: CMPersistentTrackID, span: TimeSpan, curve: SpeedCurve, keepsPitch: Bool, clip: String
    ) async throws -> URL {
        let key = "\(file.lastPathComponent)|\(trackID)|\(span.start)|\(span.end)|\(curve.points)|\(keepsPitch)"
        let name = "Cue-curve-\(stableHash(key))"
        let url = URL.temporaryDirectory.appending(path: name + ".caf")
        if rendered.withLock({ $0.files[name] }) != nil, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            remember(name, at: url, for: clip)
            return url
        }
        let asset = AVURLAsset(url: file)
        guard let track = try await asset.loadTrack(withTrackID: trackID) else { throw RenderError.unreadable }
        // Written under a name of its own and moved in when complete: a render stopped halfway never leaves a short file.
        let partial = URL.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString.prefix(8)).caf")
        do {
            try await renderFile(asset: asset, track: track, span: span, curve: curve, keepsPitch: keepsPitch, to: partial)
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                // Another build rendered the same sound meanwhile.
                try? FileManager.default.removeItem(at: partial)
            } else {
                try FileManager.default.moveItem(at: partial, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        remember(name, at: url, for: clip)
        return url
    }

    /// `name` is the clip's newest render; its renders older than the last `keptPerClip` that no other clip uses are removed.
    private static func remember(_ name: String, at url: URL, for clip: String) {
        let removed: [URL] = rendered.withLock { state in
            state.files[name] = url
            var names = state.byClip[clip] ?? []
            names.removeAll { $0 == name }
            names.append(name)
            let dropped = names.count > keptPerClip ? Array(names.prefix(names.count - keptPerClip)) : []
            names.removeFirst(dropped.count)
            state.byClip[clip] = names
            let stillUsed = Set(state.byClip.values.joined())
            return dropped.filter { !stillUsed.contains($0) }.compactMap { old in state.files.removeValue(forKey: old) }
        }
        for url in removed { try? FileManager.default.removeItem(at: url) }
    }

    /// The format the sound is read and rendered in: its own rate, its channels (up to two), 32-bit float.
    private static func format(of track: AVAssetTrack) async throws -> AVAudioFormat {
        let descriptions = try await track.load(.formatDescriptions)
        let basic = descriptions.first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        let rate = basic.map { $0.mSampleRate > 0 ? $0.mSampleRate : 44_100 } ?? 44_100
        let channels = AVAudioChannelCount(min(2, max(1, Int(basic?.mChannelsPerFrame ?? 1))))
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels) else { throw RenderError.unreadable }
        return format
    }

    /// Plays the stretch through the time-pitch unit, offline, its rate set from the curve before each block, until the
    /// curve's length is written (the unit's own delay skipped at the start). The recording is read as the player needs it,
    /// a second at a time, never more than `aheadSeconds` ahead.
    private static func renderFile(
        asset: AVAsset, track: AVAssetTrack, span: TimeSpan, curve: SpeedCurve, keepsPitch: Bool, to url: URL
    ) async throws {
        let format = try await Self.format(of: track)
        let source = try SoundChunkReader(asset: asset, track: track, span: span, format: format, chunkSeconds: chunkSeconds)
        defer { source.cancel() }
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
        let rate = format.sampleRate
        let ahead = rate * aheadSeconds
        // Frames of the recording handed to the player, and played by it (as the rates say).
        var scheduled = 0.0, consumed = 0.0
        func feed() async throws {
            while scheduled - consumed < ahead, let chunk = try await source.next() {
                schedule(chunk, on: player)
                scheduled += Double(chunk.frameLength)
            }
        }
        try await feed()
        try player.playAudio()
        let length = span.duration
        let wanted = AVAudioFramePosition((curve.editedLength(sourceLength: length) * rate).rounded())
        let delay = AVAudioFramePosition((pitch.latency * rate).rounded())
        guard let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: block) else { throw RenderError.cantRender }
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        var written: AVAudioFramePosition = 0
        var renderedFrames: AVAudioFramePosition = 0
        while written < wanted {
            try Task.checkCancellation()
            // The speed where the sound is now: the edited moment of the next frame written.
            let edited = Double(max(0, renderedFrames - delay)) / rate
            let position = curve.sourceOffset(forEdited: edited, sourceLength: length) / max(0.001, length)
            let speed = curve.speed(at: position)
            if keepsPitch { timePitch.rate = Float(speed) } else { varispeed.rate = Float(speed) }
            let status = try engine.renderOffline(block, to: output)
            guard status == .success else { throw RenderError.cantRender }
            let frames = AVAudioFramePosition(output.frameLength)
            renderedFrames += frames
            consumed += Double(frames) * speed
            try await feed()
            // The unit's delay at the start isn't part of the sound.
            let skip = min(max(0, delay - (renderedFrames - frames)), frames)
            let keep = min(frames - skip, wanted - written)
            guard keep > 0 else { continue }
            if skip > 0 || keep < frames {
                guard let part = AVAudioPCMBuffer(pcmFormat: output.format, frameCapacity: AVAudioFrameCount(keep)),
                      let from = output.floatChannelData, let into = part.floatChannelData else { throw RenderError.cantRender }
                part.frameLength = AVAudioFrameCount(keep)
                for channel in 0..<Int(output.format.channelCount) {
                    into[channel].update(from: from[channel] + Int(skip), count: Int(keep))
                }
                try file.write(from: part)
            } else {
                try file.write(from: output)
            }
            written += keep
        }
    }

    /// Queues `buffer` on `player` without waiting for it to play (the async form returns only once it has played, which in
    /// offline rendering is never before the next render).
    private static func schedule(_ buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode) {
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
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
