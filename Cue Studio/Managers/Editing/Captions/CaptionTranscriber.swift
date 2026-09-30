//
//  CaptionTranscriber.swift
//  Cue Studio
//

import AVFoundation
import Speech

/// Transcribes a take on the device, word by word with timings, so captions follow the voice and
/// Clean Up can find filler words and retakes. Same recognizers and languages as Voice Following
/// (`SpeechLocaleResolver`): nothing leaves the iPhone and nothing is paid per use.
nonisolated enum CaptionTranscriber {
    /// The words and the language they were heard in. Throws `SpeechUnavailableReason` when no
    /// speech model on this device can listen in that language (never another language instead),
    /// and `CancellationError` when the task is cancelled. Runs off the main actor.
    @concurrent
    static func transcript(
        in audio: URL, language: SpeechLanguageRequest, script: String = "",
        resolver: SpeechLocaleResolver = SpeechLocaleResolver(),
        progress: (@Sendable (CaptionProgress) -> Void)? = nil
    ) async throws -> TakeTranscript {
        progress?(.preparing)
        let route: SpeechRoute
        switch await resolver.resolve(language, scriptText: script) {
        case .success(let resolved): route = resolved
        case .failure(let reason): throw reason
        }
        try Task.checkCancellation()
        let words: [TimedWord]
        switch route.engine {
        case .transcriber:
            let transcriber = SpeechTranscriber(locale: route.locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
            words = try await transcribe(audio, with: transcriber, results: transcriber.results, progress: progress) { $0.text }
        case .dictation:
            let dictation = DictationTranscriber(
                locale: route.locale, contentHints: [], transcriptionOptions: [], reportingOptions: [],
                attributeOptions: [.audioTimeRange]
            )
            words = try await transcribe(audio, with: dictation, results: dictation.results, progress: progress) { $0.text }
        }
        return TakeTranscript(words: words, languageCode: route.locale.language.languageCode?.identifier ?? "en")
    }

    private static func transcribe<Results: AsyncSequence & Sendable>(
        _ audio: URL, with module: any SpeechModule, results: Results,
        progress: (@Sendable (CaptionProgress) -> Void)?,
        text: @escaping @Sendable (Results.Element) -> AttributedString
    ) async throws -> [TimedWord] where Results.Element: Sendable {
        let modules: [any SpeechModule] = [module]
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            progress?(.downloading(nil))
            let watcher = Task {
                // The system's download reports its own progress; read it while it runs.
                while !Task.isCancelled {
                    progress?(.downloading(request.progress.fractionCompleted))
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
            defer { watcher.cancel() }
            try await request.downloadAndInstall()
        }
        try Task.checkCancellation()
        let file = try AVAudioFile(forReading: audio)
        let length = Double(file.length) / max(1, file.processingFormat.sampleRate)
        progress?(.transcribing(0))
        let collector = Task {
            var words: [TimedWord] = []
            for try await result in results {
                let heard = text(result)
                for run in heard.runs {
                    guard let range = heard[run.range].audioTimeRange else { continue }
                    let text = String(heard[run.range].characters)
                    words += spread(text, start: range.start.seconds, end: range.end.seconds)
                    if length > 0 { progress?(.transcribing(min(1, range.end.seconds / length))) }
                }
            }
            return words
        }
        let analyzer = SpeechAnalyzer(modules: modules)
        try await withTaskCancellationHandler {
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } onCancel: {
            collector.cancel()
            Task { await analyzer.cancelAndFinishNow() }
        }
        try Task.checkCancellation()
        return try await collector.value
    }

    /// A run can hold several words; they share its time evenly and are marked as estimated.
    /// Languages written without spaces (Japanese, Chinese, Thai) are split into dictionary words.
    static func spread(_ text: String, start: TimeInterval, end: TimeInterval) -> [TimedWord] {
        let pieces = CaptionText.words(in: text)
        guard !pieces.isEmpty, end > start else { return [] }
        let step = (end - start) / Double(pieces.count)
        let isEstimated = pieces.count > 1
        return pieces.enumerated().map { index, word in
            TimedWord(text: word, start: start + Double(index) * step, end: start + Double(index + 1) * step, isEstimated: isEstimated)
        }
    }
}
