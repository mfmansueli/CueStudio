//
//  CaptionTranscriber.swift
//  Cue Studio
//

import AVFoundation
import Speech

/// Transcribes a take on the device, word by word with timings, so captions follow the voice.
nonisolated enum CaptionTranscriber {
    /// Nil when there is no speech model for the script's language.
    static func words(in audio: URL, script: String) async throws -> [TimedWord]? {
        guard SpeechTranscriber.isAvailable, let locale = await SpeechRecognitionManager.locale(for: script) else { return nil }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
        let modules: [any SpeechModule] = [transcriber]
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            try await request.downloadAndInstall()
        }
        let collector = Task {
            var words: [TimedWord] = []
            for try await result in transcriber.results {
                for run in result.text.runs {
                    guard let range = result.text[run.range].audioTimeRange else { continue }
                    let text = String(result.text[run.range].characters)
                    words += spread(text, start: range.start.seconds, end: range.end.seconds)
                }
            }
            return words
        }
        let file = try AVAudioFile(forReading: audio)
        let analyzer = SpeechAnalyzer(modules: modules)
        if let last = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collector.value
    }

    /// A run can hold several words; they share its time evenly.
    static func spread(_ text: String, start: TimeInterval, end: TimeInterval) -> [TimedWord] {
        let pieces = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !pieces.isEmpty, end > start else { return [] }
        let step = (end - start) / Double(pieces.count)
        return pieces.enumerated().map { index, word in
            TimedWord(text: word, start: start + Double(index) * step, end: start + Double(index + 1) * step)
        }
    }
}
