//
//  VoiceEffectRenderer.swift
//  Cue Studio
//

import AVFoundation

/// A voice effect (`VoiceEffectSetting`) on a stretch of a sound, made on the iPhone, offline, into a file of its own exactly as
/// long: Radio, Megaphone, Robot, Echo and Big hall shaped by Cue sample by sample (`VoiceEffectShaper`); Deep voice and Chipmunk
/// through Apple's time-pitch unit at the same speed, so the voice stays on the lips (the unit's delay at the start is taken
/// off). The result is as loud as the speech it came from (an effect changes the sound, not the volume, so comparing with the
/// original never lies; within `largestMatch`) and stays under `AudioCeiling`. Streamed like a curved clip's sound
/// (`SoundChunkReader`), off the main thread and stopped as soon as the build that wants it is dropped; written once into the
/// temporary folder (`Cue-voicefx-…`) and reused while the sound and the effect don't change (`RenderedSoundFiles`).
nonisolated enum VoiceEffectRenderer {
    enum RenderError: Error { case unreadable, cantRender }

    /// Frames rendered at a time through the time-pitch unit.
    static let block: AVAudioFrameCount = 4096
    /// Seconds of the sound read at a time.
    static let chunkSeconds = 1.0
    /// The most the effect's sound is brought up or down to sound as loud as the voice was, in dB.
    static let largestMatch: Float = 12
    /// Renders kept per clip: the newest, and the one before it (the preview may still be playing it).
    static let keptPerClip = 2

    private static let rendered = RenderedSoundFiles(kept: keptPerClip)

    /// The file playing `span` of the sound track `trackID` of `file` (the first sound track and the whole file when nil) with
    /// `setting`, as long as the stretch. `clip` names the clip it's for, whose older renders go once replaced. Throws
    /// `CancellationError` when the task is cancelled.
    @concurrent
    static func render(
        file: URL, trackID: CMPersistentTrackID? = nil, span: TimeSpan? = nil, setting: VoiceEffectSetting, clip: String
    ) async throws -> URL {
        let spanKey = span.map { "\($0.start)-\($0.end)" } ?? "all"
        let key = "\(file.lastPathComponent)|\(trackID ?? 0)|\(spanKey)|\(setting.effect.rawValue)|\(setting.amount)|\(VoiceEffect.version)"
        let name = "Cue-voicefx-\(RenderedSoundFiles.stableHash(key))"
        let url = URL.temporaryDirectory.appending(path: name + ".caf")
        if rendered.file(named: name) != nil {
            rendered.remember(name, at: url, for: clip)
            return url
        }
        let asset = AVURLAsset(url: file)
        let loaded = if let trackID { try await asset.loadTrack(withTrackID: trackID) } else { try await asset.loadTracks(withMediaType: .audio).first }
        guard let track = loaded else { throw RenderError.unreadable }
        let stretch: TimeSpan
        if let span { stretch = span } else { stretch = TimeSpan(start: 0, end: try await asset.load(.duration).seconds) }
        // Written under a name of its own and moved in when complete: a render stopped halfway never leaves a short file.
        let partial = URL.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString.prefix(8)).caf")
        var made: [URL] = [partial]
        defer { for file in made { try? FileManager.default.removeItem(at: file) } }
        let levels = try await renderFile(asset: asset, track: track, span: stretch, setting: setting, to: partial)
        try Task.checkCancellation()
        var finished = partial
        if let dry = levels.dry, let wet = levels.wet {
            finished = try AudioCeiling.leveled(finished, gain: min(max(dry - wet, -largestMatch), largestMatch))
            made.append(finished)
        }
        finished = try AudioCeiling.keepingUnder(finished)
        made.append(finished)
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            // Another build rendered the same sound meanwhile.
        } else {
            try FileManager.default.moveItem(at: finished, to: url)
        }
        rendered.remember(name, at: url, for: clip)
        return url
    }

    /// Writes the stretch with the effect into `url`. Returns the speech level going in and coming out.
    private static func renderFile(
        asset: AVAsset, track: AVAssetTrack, span: TimeSpan, setting: VoiceEffectSetting, to url: URL
    ) async throws -> (dry: Float?, wet: Float?) {
        let format = try await SoundChunkReader.format(of: track)
        let source = try SoundChunkReader(asset: asset, track: track, span: span, format: format, chunkSeconds: chunkSeconds)
        defer { source.cancel() }
        let output = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        var dry = SoundLevelMeter(sampleRate: format.sampleRate), wet = SoundLevelMeter(sampleRate: format.sampleRate)
        if let shaper = VoiceEffectShaper(setting: setting, sampleRate: format.sampleRate) {
            var shapers = [VoiceEffectShaper](repeating: shaper, count: Int(format.channelCount))
            var written = false
            while let chunk = try await source.next() {
                try Task.checkCancellation()
                dry.add(chunk)
                guard let channels = chunk.floatChannelData else { throw RenderError.cantRender }
                for channel in shapers.indices {
                    let samples = channels[channel]
                    for index in 0..<Int(chunk.frameLength) { samples[index] = shapers[channel].process(samples[index]) }
                }
                wet.add(chunk)
                try output.write(from: chunk)
                written = true
            }
            guard written else { throw RenderError.unreadable }
        } else {
            try await pitchShift(source, format: format, cents: pitch(of: setting), into: output, dry: &dry, wet: &wet)
        }
        return (dry.speechLevel, wet.speechLevel)
    }

    /// Deep voice goes down 3 to 7 semitones, Chipmunk up 4 to 9, as "Amount" says.
    private static func pitch(of setting: VoiceEffectSetting) -> Float {
        let amount = Float(setting.amount)
        return setting.effect == .chipmunk ? 400 + 500 * amount : -(300 + 400 * amount)
    }

    /// The stretch through the time-pitch unit at its own speed, `cents` higher or lower, until all of it is written (the
    /// unit's delay at the start skipped). Read as the player needs it, never more than a few seconds ahead.
    private static func pitchShift(
        _ source: SoundChunkReader, format: AVAudioFormat, cents: Float, into output: AVAudioFile,
        dry: inout SoundLevelMeter, wet: inout SoundLevelMeter
    ) async throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.pitch = cents
        engine.attach(player)
        engine.attach(timePitch)
        try engine.connectNode(player, to: timePitch, format: format)
        try engine.connectNode(timePitch, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: block)
        try engine.start()
        defer {
            player.stop()
            engine.stop()
        }
        let ahead = AVAudioFramePosition(format.sampleRate * 2)
        var scheduled: AVAudioFramePosition = 0, renderedFrames: AVAudioFramePosition = 0, written: AVAudioFramePosition = 0
        var isFinished = false
        func feed() async throws {
            while !isFinished, scheduled - renderedFrames < ahead {
                guard let chunk = try await source.next() else {
                    isFinished = true
                    break
                }
                dry.add(chunk)
                schedule(chunk, on: player)
                scheduled += AVAudioFramePosition(chunk.frameLength)
            }
        }
        try await feed()
        guard scheduled > 0 else { throw RenderError.unreadable }
        try player.playAudio()
        let delay = AVAudioFramePosition((timePitch.latency * format.sampleRate).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: block) else { throw RenderError.cantRender }
        while written < scheduled || !isFinished {
            try Task.checkCancellation()
            guard try engine.renderOffline(block, to: buffer) == .success else { throw RenderError.cantRender }
            let frames = AVAudioFramePosition(buffer.frameLength)
            renderedFrames += frames
            try await feed()
            let skip = min(max(0, delay - (renderedFrames - frames)), frames)
            let keep = min(frames - skip, scheduled - written)
            guard keep > 0 else { continue }
            guard let part = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(keep)),
                  let from = buffer.floatChannelData, let into = part.floatChannelData else { throw RenderError.cantRender }
            part.frameLength = AVAudioFrameCount(keep)
            for channel in 0..<Int(buffer.format.channelCount) {
                into[channel].update(from: from[channel] + Int(skip), count: Int(keep))
            }
            wet.add(part)
            try output.write(from: part)
            written += keep
        }
    }

    /// Queues `buffer` on `player` without waiting for it to play (the async form returns only once it has played, which in
    /// offline rendering is never before the next render).
    private static func schedule(_ buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode) {
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
}
