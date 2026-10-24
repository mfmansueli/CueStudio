//
//  SpokenLanguageIdentifier.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Which of a few likely languages a take is spoken in, for captions that would otherwise guess it: a take without a script (the
/// Script Language, the iPhone's languages, the interface's and English), or one whose spoken language was picked unlike its
/// script's (most likely by mistake). The first seconds of speech are heard in each, and the language whose recognizer understood
/// them best wins; the first candidate (what the take would be heard in otherwise) keeps a near tie. Nothing changes when it can't
/// tell: no speech, or a recognizer that can't rate its words (`TranscriberLanguageListener`).
nonisolated struct SpokenLanguageIdentifier: Sendable {
    /// Seconds of speech heard in each language.
    static let sampleLength: TimeInterval = 10
    /// Fewer words than this is a language that heard almost nothing.
    static let minimumWords = 3
    /// How much better another language has to be understood to win over the first.
    static let tieMargin = 0.02
    /// How well another language has to be understood to win at all: the language spoken scored 0.87 or more on an iPhone, while a
    /// wrong one that won only because the one spoken wasn't on the iPhone scored 0.75 at most (Spanish hearing French).
    static let minimumConfidence = 0.85
    /// A language understood well, if not quite `minimumConfidence`, still wins when every other language heard it this much
    /// worse: a Hindi reading scored 0.85 (just under) against English's 0.26 and was kept as Portuguese. Where the language
    /// spoken wasn't among them, the best wrong one scored 0.73 at most (people's voices on an iPhone, FLEURS).
    static let clearConfidence = 0.8
    static let clearMargin = 0.3

    var listener: any SpokenLanguageListening = TranscriberLanguageListener()

    /// The language among `candidates` the speech in `audio` is in; nil when there is nothing to choose or it can't tell (the
    /// first stays). Throws `CancellationError` when cancelled.
    @concurrent
    func spokenLanguage(in audio: URL, among candidates: [CueLanguage]) async throws -> CueLanguage? {
        guard candidates.count > 1, let first = candidates.first, let clip = try Self.clip(of: audio) else { return nil }
        defer { try? FileManager.default.removeItem(at: clip) }
        // Every candidate is about to take a place: none makes room for another.
        SpeechLocaleReservation.willUse(candidates.map(\.locale))
        var scores: [CueLanguage: SpokenLanguageScore] = [:]
        for (index, language) in candidates.enumerated() {
            try Task.checkCancellation()
            // The first is the one captions would use anyway, so its model may be downloaded; the others only compare when they're
            // already on the iPhone.
            guard let score = try await score(of: clip, in: language, mayDownload: index == 0) else {
                // Without the first, there is nothing to compare with.
                if index == 0 { return nil }
                continue
            }
            scores[language] = score
        }
        return Self.pick(scores, first: first)
    }

    /// A language that fails to listen (its model won't load, the system's places are taken) can't be judged; only a stop goes up.
    private func score(of clip: URL, in language: CueLanguage, mayDownload: Bool) async throws -> SpokenLanguageScore? {
        do {
            return try await listener.score(of: clip, in: language, mayDownload: mayDownload)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    /// The best understood language with enough words, unless the first is within `tieMargin` of it; nil when none heard enough,
    /// or another one won without being understood well (`minimumConfidence`) or clearly better than the rest (`clearMargin`).
    ///
    /// A recognizer writes what it hears in the language it hears it in: on an English reading, Spanish's and Portuguese's wrote
    /// English, and Spanish scored 0.92 against English's 0.91 (people's voices on an iPhone). So one that wrote in another
    /// language drops out; one whose writing can't be read (Hindi's, in Latin letters) stays. When every one wrote in another,
    /// the language spoken isn't among them: nothing changes.
    static func pick(_ scores: [CueLanguage: SpokenLanguageScore], first: CueLanguage) -> CueLanguage? {
        let heard = scores.filter { $0.value.words >= minimumWords && ($0.value.writtenIn == nil || $0.value.writtenIn == $0.key) }
        guard let best = heard.max(by: { $0.value.confidence < $1.value.confidence }) else { return nil }
        if let kept = heard[first], kept.confidence + tieMargin >= best.value.confidence { return first }
        let runnerUp = heard.filter { $0.key != best.key }.map(\.value.confidence).max() ?? 0
        let clear = best.value.confidence >= clearConfidence && best.value.confidence - runnerUp >= clearMargin
        return best.value.confidence >= minimumConfidence || clear ? best.key : nil
    }

    /// The first `sampleLength` seconds of speech in `audio`, as a file of their own; nil when there is no speech.
    private static func clip(of audio: URL) throws -> URL? {
        let interval = 0.05
        guard let spoken = TranscriptTimingCheck.spokenSpan(levels: try AudioLevelReader.levels(of: audio, interval: interval), interval: interval) else {
            return nil
        }
        let input = try AVAudioFile(forReading: audio)
        let format = input.processingFormat
        let start = AVAudioFramePosition(max(0, spoken.start - 0.2) * format.sampleRate)
        let count = AVAudioFrameCount(max(0, min(Double(input.length - start), sampleLength * format.sampleRate)))
        guard count > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { return nil }
        input.framePosition = start
        try input.read(into: buffer, frameCount: count)
        let url = URL.temporaryDirectory.appending(path: "spoken-\(UUID().uuidString).caf")
        let output = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try output.write(from: buffer)
        return url
    }
}
