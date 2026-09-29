//
//  CaptionTranscriber.swift
//  Cue Studio
//

import AVFoundation
import Speech

/// Transcribes a take on the device, word by word with timings, so captions follow the voice and
/// Clean Up can find filler words and retakes. Same recognizers and languages as Voice Following
/// (`SpeechLocaleResolver`).
nonisolated enum CaptionTranscriber {
    /// The words and the language they were heard in, for captions and Clean Up. Nil when no speech
    /// model on this device can listen in that language.
    static func transcript(
        in audio: URL, language: SpeechLanguageRequest, script: String = "", resolver: SpeechLocaleResolver = SpeechLocaleResolver()
    ) async throws -> TakeTranscript? {
        guard case .success(let route) = await resolver.resolve(language, scriptText: script) else { return nil }
        let words: [TimedWord]
        switch route.engine {
        case .transcriber:
            let transcriber = SpeechTranscriber(locale: route.locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
            words = try await transcribe(audio, with: transcriber, results: transcriber.results) { $0.text }
        case .dictation:
            let dictation = DictationTranscriber(locale: route.locale, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
            words = try await transcribe(audio, with: dictation, results: dictation.results) { $0.text }
        }
        return TakeTranscript(words: words, languageCode: route.locale.language.languageCode?.identifier ?? "en")
    }

    private static func transcribe<Results: AsyncSequence & Sendable>(
        _ audio: URL, with module: any SpeechModule, results: Results,
        text: @escaping @Sendable (Results.Element) -> AttributedString
    ) async throws -> [TimedWord] where Results.Element: Sendable {
        let modules: [any SpeechModule] = [module]
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            try await request.downloadAndInstall()
        }
        let collector = Task {
            var words: [TimedWord] = []
            for try await result in results {
                let heard = text(result)
                for run in heard.runs {
                    guard let range = heard[run.range].audioTimeRange else { continue }
                    let text = String(heard[run.range].characters)
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

    /// A run can hold several words; they share its time evenly. Languages written without spaces
    /// (Japanese, Chinese, Thai) are split into dictionary words.
    static func spread(_ text: String, start: TimeInterval, end: TimeInterval) -> [TimedWord] {
        let pieces = text.split(whereSeparator: \.isWhitespace).flatMap { piece -> [String] in
            let piece = String(piece)
            guard WordSegmenter.containsUnspacedScript(piece) else { return [piece] }
            return WordSegmenter.segments(of: piece).map(\.word)
        }
        guard !pieces.isEmpty, end > start else { return [] }
        let step = (end - start) / Double(pieces.count)
        return pieces.enumerated().map { index, word in
            TimedWord(text: word, start: start + Double(index) * step, end: start + Double(index + 1) * step)
        }
    }
}
