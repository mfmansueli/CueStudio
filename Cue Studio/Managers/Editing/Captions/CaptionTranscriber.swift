//
//  CaptionTranscriber.swift
//  Cue Studio
//

import AVFoundation
import Speech

/// Transcribes a take on the device, word by word with timings, so captions follow the voice and
/// Clean Up can find filler words and retakes. Same recognizers and languages as Voice Following
/// (`SpeechLocaleResolver`): nothing leaves the iPhone and nothing is paid per use.
///
/// A recognizer listens in one language, and creators mix them: an English opening and a Portuguese
/// rest, or English phrases in Portuguese. When the take's script uses another language for a
/// stretch of its own (`ScriptLanguageRuns`), the take is heard in that language too and each
/// stretch comes from the recognizer that lines up with it (`MixedLanguageMerge`). A language this
/// iPhone can't listen in is left out, and the take is heard in the main one alone.
nonisolated enum CaptionTranscriber {
    /// The words and the language they were heard in (the main one). Throws `SpeechUnavailableReason`
    /// when no speech model on this device can listen in the main language (never another language
    /// instead), and `CancellationError` when the task is cancelled. Runs off the main actor.
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
        let code = route.locale.language.languageCode?.identifier ?? "en"
        let reading = ScriptLanguageRuns.reading(of: script, language: route.language)
        var routes = [(code: code, route: route)]
        var unheard: [String] = []
        for other in ScriptLanguageRuns.foreignCodes(in: reading, besides: code) {
            guard let cue = CueLanguage.matching(languageCode: other),
                  case .success(let found) = await resolver.resolve(.language(cue), scriptText: script) else {
                // A language this iPhone can't listen in: its stretches stay out, and the creator is told.
                unheard.append(other)
                continue
            }
            routes.append((other, found))
        }
        var heard: [MixedLanguageMerge.Heard] = []
        for (index, entry) in routes.enumerated() {
            try Task.checkCancellation()
            do {
                let words = try await listen(in: audio, route: entry.route, script: script, progress: share(progress, pass: index, of: routes.count))
                heard.append(.init(code: entry.code, words: words))
            } catch {
                // The main language must be heard; another one this iPhone can't download or run only costs
                // its stretch, which is reported rather than lost without a word.
                if index == 0 || error is CancellationError { throw error }
                unheard.append(entry.code)
            }
        }
        var words = MixedLanguageMerge.merge(heard, primary: code, reading: reading)
        // Times that don't fit the recording (a recognizer that finishes early) are never passed off as measured.
        if let levels = try? AudioLevelReader.levels(of: audio, interval: 0.05) {
            words = TranscriptTimingCheck.reconciled(words, spoken: TranscriptTimingCheck.spokenSpan(levels: levels, interval: 0.05))
        }
        return TakeTranscript(words: words, languageCode: Self.transcriptCode(for: route, code: code), unheardLanguages: unheard)
    }

    /// The code a transcript is kept under: the language's ("pt"), except Chinese, which carries its
    /// writing system ("zh-Hant") because the code alone would read Traditional characters as Simplified
    /// when the captions are built, reused or translated.
    private static func transcriptCode(for route: SpeechRoute, code: String) -> String {
        guard code == "zh" else { return code }
        return CueLanguage.matching(language: route.locale.language)?.chineseScriptIdentifier ?? code
    }

    /// The take heard in one language.
    private static func listen(
        in audio: URL, route: SpeechRoute, script: String, progress: (@Sendable (CaptionProgress) -> Void)?
    ) async throws -> [TimedWord] {
        // The script's names and long words, so the recognizer listens for them (it still writes what it hears).
        let terms = ScriptVocabulary.terms(in: script, language: route.language)
        // The system holds only a few languages at a time: take a place for this one first.
        await SpeechLocaleReservation.reserve(route.locale)
        switch route.engine {
        case .transcriber:
            let transcriber = SpeechTranscriber(locale: route.locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
            return try await transcribe(
                audio, with: transcriber, results: transcriber.results, language: route.language, terms: terms, progress: progress
            ) { $0.text }
        case .dictation:
            let dictation = DictationTranscriber(
                locale: route.locale, contentHints: [], transcriptionOptions: [], reportingOptions: [],
                attributeOptions: [.audioTimeRange]
            )
            return try await transcribe(
                audio, with: dictation, results: dictation.results, language: route.language, terms: terms, progress: progress
            ) { $0.text }
        }
    }

    /// Progress of one of several passes over the take, as a share of the whole.
    private static func share(
        _ progress: (@Sendable (CaptionProgress) -> Void)?, pass: Int, of count: Int
    ) -> (@Sendable (CaptionProgress) -> Void)? {
        guard let progress, count > 1 else { return progress }
        return { update in
            if case .transcribing(let done) = update {
                progress(.transcribing((Double(pass) + done) / Double(count)))
            } else {
                progress(update)
            }
        }
    }

    private static func transcribe<Results: AsyncSequence & Sendable>(
        _ audio: URL, with module: any SpeechModule, results: Results, language: CueLanguage?, terms: [String],
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
                    words += spread(text, start: range.start.seconds, end: range.end.seconds, language: language)
                    if length > 0 { progress?(.transcribing(min(1, range.end.seconds / length))) }
                }
            }
            return words
        }
        let analyzer = SpeechAnalyzer(modules: modules)
        if !terms.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = terms
            // Only a hint: a model that ignores it still listens.
            try? await analyzer.setContext(context)
        }
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

    /// A run can hold several words; keep its measured interval on all of them. There is no
    /// evidence for where any individual word starts, so never divide the duration arbitrarily.
    /// Languages written without spaces (Japanese, Chinese, Thai) are split into dictionary words,
    /// in the language heard (`WordTokenizer`, the same cut as Voice Following's).
    static func spread(_ text: String, start: TimeInterval, end: TimeInterval, language: CueLanguage? = nil) -> [TimedWord] {
        let pieces = CaptionText.words(in: text, language: language)
        guard !pieces.isEmpty, end > start else { return [] }
        let isEstimated = pieces.count > 1
        return pieces.map { word in
            TimedWord(text: word, start: start, end: end, isEstimated: isEstimated)
        }
    }
}
