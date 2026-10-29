//
//  NarrationMaker.swift
//  Cue Studio
//

import AVFoundation
import NaturalLanguage

/// Text to speech's sound: the voice says the text at its natural pace (`NarrationSpeaking`), the silence it leaves before the
/// first word and after the last is taken off, it's brought to the speed asked for with its pitch kept (through the same
/// time-pitch rendering as a clip's speed curve, `CurveSoundRenderer`, so 1.25× is exactly 1.25×: the synthesizer's own rate
/// isn't proportional and differs between voices), and to the level of a well-recorded voice, never over `AudioCeiling`. Made
/// is a voice-over file in `EditMediaFiles` (AAC, mono, like a recorded one); a preview is the first sentence the same way, in
/// the temporary folder. Everything stays on the iPhone.
nonisolated enum NarrationMaker {
    enum MakeError: Error { case unreadable, silent }

    /// The speech level a narration is brought to (`SpeechLoudness`, dBFS): a clear voice with room under the ceiling.
    static let speechLevel: Float = -18
    /// Quieter than this (dBFS, over 20 ms) is silence at the ends.
    static let silenceFloor: Float = -50
    /// Silence kept before the first word and after the last.
    static let edgePad: TimeInterval = 0.06
    /// The most a preview says.
    static let previewCharacters = 160

    /// Says `narration` into a new voice-over file. Returns its name in `EditMediaFiles` and its length.
    @concurrent
    static func make(_ narration: SpokenNarration, speaker: any NarrationSpeaking) async throws -> (fileName: String, duration: TimeInterval) {
        let sound = try await said(narration.text, narration: narration, speaker: speaker, clip: "narration")
        defer { try? FileManager.default.removeItem(at: sound) }
        try Task.checkCancellation()
        let (name, url) = try EditMediaFiles.newFile(pathExtension: "m4a")
        do {
            let duration = try encode(sound, to: url)
            return (name, duration)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// The first sentence of `narration` said the way it will be, to hear before making the whole of it.
    @concurrent
    static func preview(_ narration: SpokenNarration, speaker: any NarrationSpeaking) async throws -> URL {
        try await said(excerpt(of: narration.text), narration: narration, speaker: speaker, clip: "narration-preview")
    }

    /// The first sentence, or the first `previewCharacters` cut at a word.
    static func excerpt(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed
        var first = trimmed
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            first = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return false
        }
        guard first.count > previewCharacters else { return first }
        let cut = first.prefix(previewCharacters)
        return cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)
    }

    // MARK: - Making

    /// `text` said by the narration's voice, trimmed, at its speed and level, as a file in the temporary folder.
    private static func said(_ text: String, narration: SpokenNarration, speaker: any NarrationSpeaking, clip: String) async throws -> URL {
        let raw = try await speaker.speak(text, voiceID: narration.voiceID)
        var made: Set<URL> = [raw]
        defer { for file in made { try? FileManager.default.removeItem(at: file) } }
        var sound = try trimmed(raw)
        made.insert(sound)
        try Task.checkCancellation()
        if abs(narration.speed - 1) > 0.005 {
            sound = try await stretched(sound, to: narration.speed, clip: clip)
            made.insert(sound)
        }
        if let level = try SpeechLoudness.level(ofAudio: sound) {
            sound = try AudioCeiling.leveled(sound, gain: speechLevel - level)
            made.insert(sound)
        }
        sound = try AudioCeiling.keepingUnder(sound)
        // The finished file is the caller's.
        made.remove(sound)
        return sound
    }

    /// The sound without the silence before the first word and after the last (`edgePad` kept).
    static func trimmed(_ url: URL) throws -> URL {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard file.length > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw MakeError.unreadable
        }
        try file.read(into: buffer)
        guard let samples = buffer.floatChannelData?[0] else { throw MakeError.unreadable }
        let frames = Int(buffer.frameLength)
        let window = max(1, Int(format.sampleRate * 0.02))
        let floor = pow(10, silenceFloor / 20)
        func isHeard(_ start: Int) -> Bool {
            let end = min(frames, start + window)
            var sum: Float = 0
            for index in start..<end { sum += samples[index] * samples[index] }
            return sqrt(sum / Float(max(1, end - start))) > floor
        }
        guard let first = stride(from: 0, to: frames, by: window).first(where: isHeard),
              let last = stride(from: 0, to: frames, by: window).reversed().first(where: isHeard) else { throw MakeError.silent }
        let pad = Int(format.sampleRate * edgePad)
        let start = max(0, first - pad), end = min(frames, last + window + pad)
        let output = URL.temporaryDirectory.appending(path: "Cue-speech-\(UUID().uuidString.prefix(8)).caf")
        let written = try AVAudioFile(forWriting: output, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let part = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(end - start)),
              let from = buffer.floatChannelData, let into = part.floatChannelData else { throw MakeError.unreadable }
        part.frameLength = AVAudioFrameCount(end - start)
        for channel in 0..<Int(format.channelCount) { into[channel].update(from: from[channel] + start, count: end - start) }
        try written.write(from: part)
        return output
    }

    /// The sound at `speed` times its pace, its pitch kept: a speed "curve" that never changes, through `CurveSoundRenderer`.
    private static func stretched(_ url: URL, to speed: Double, clip: String) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw MakeError.unreadable }
        let length = try await asset.load(.duration).seconds
        let curve = SpeedCurve(points: [.init(position: 0, speed: speed), .init(position: 1, speed: speed)])
        let rendered = try await CurveSoundRenderer.render(
            file: url, trackID: track.trackID, span: TimeSpan(start: 0, end: length), curve: curve, keepsPitch: true, clip: clip
        )
        // A copy of its own: the renderer may remove its file when it renders this clip again.
        let copy = URL.temporaryDirectory.appending(path: "Cue-speech-\(UUID().uuidString.prefix(8)).caf")
        try FileManager.default.copyItem(at: rendered, to: copy)
        return copy
    }

    /// `url` as AAC in `destination`, mono at its own rate. Returns its length.
    private static func encode(_ url: URL, to destination: URL) throws -> TimeInterval {
        let input = try AVAudioFile(forReading: url)
        let rate = input.processingFormat.sampleRate
        guard let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: 16_384),
              let monoBuffer = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: 16_384) else { throw MakeError.unreadable }
        let output = try AVAudioFile(
            forWriting: destination,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ],
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        var frames: AVAudioFramePosition = 0
        while input.framePosition < input.length {
            try input.read(into: buffer)
            guard buffer.frameLength > 0, let from = buffer.floatChannelData?[0], let into = monoBuffer.floatChannelData?[0] else { break }
            into.update(from: from, count: Int(buffer.frameLength))
            monoBuffer.frameLength = buffer.frameLength
            try output.write(from: monoBuffer)
            frames += AVAudioFramePosition(buffer.frameLength)
        }
        return Double(frames) / rate
    }
}
