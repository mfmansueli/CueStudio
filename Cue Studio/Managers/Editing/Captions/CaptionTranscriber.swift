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
        // No word starts in the silence before the voice, times that don't fit the recording (a recognizer that finishes early)
        // are never passed off as measured, and words that run into each other meet where the voice dips between them.
        if let fine = try? AudioLevelReader.levels(of: audio, interval: 0.01) {
            let spoken = TranscriptTimingCheck.spokenSpan(levels: AudioLevelReader.combined(fine, every: 5), interval: 0.05)
            words = TranscriptTimingCheck.reconciled(TranscriptTimingCheck.startingWithTheVoice(words, spoken: spoken), spoken: spoken)
            words = WordBoundaries.atQuietestPoints(words, levels: fine, interval: 0.01)
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
            try await install(transcriber, progress: progress)
            progress?(.transcribing(0))
            let length = try Self.length(of: audio)
            let heard = words(of: transcriber.results, language: route.language, length: length, progress: progress) { $0.text }
            // Dictation times the same words closer to the voice (`DictationTiming`), in the same pass over the take.
            guard let dictation = await dictationForTiming(route) else {
                return try await analyze(audio, with: [transcriber], terms: terms, collecting: [heard])[0]
            }
            let timed = words(of: dictation.results, language: route.language, length: length, progress: nil) { $0.text }
            let both = try await analyze(audio, with: [transcriber, dictation], terms: terms, collecting: [heard, timed])
            return DictationTiming.retimed(both[0], by: both[1])
        case .dictation:
            let dictation = DictationTranscriber(
                locale: route.locale, contentHints: [], transcriptionOptions: [], reportingOptions: [],
                attributeOptions: [.audioTimeRange]
            )
            try await install(dictation, progress: progress)
            progress?(.transcribing(0))
            let heard = words(of: dictation.results, language: route.language, length: try Self.length(of: audio), progress: progress) {
                $0.text
            }
            return try await analyze(audio, with: [dictation], terms: terms, collecting: [heard])[0]
        }
    }

    /// Dictation in `route`'s language to time the transcriber's words by, when its model is already on this iPhone (never
    /// a download for it: the take is captioned by the transcriber's times instead) and the language is written with spaces
    /// between words (in Japanese, Chinese and Thai the two cut words differently).
    private static func dictationForTiming(_ route: SpeechRoute) async -> DictationTranscriber? {
        guard route.language?.writesWithoutSpaces == false,
              let locale = await DictationTranscriber.supportedLocale(equivalentTo: route.locale) else { return nil }
        let dictation = DictationTranscriber(
            locale: locale, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange]
        )
        guard await AssetInventory.status(forModules: [dictation]) == .installed,
              await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [dictation]) != nil else { return nil }
        return dictation
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

    /// Downloads `module`'s model when this iPhone doesn't have it yet, reporting the system's progress.
    private static func install(_ module: any SpeechModule, progress: (@Sendable (CaptionProgress) -> Void)?) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
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
    }

    private static func length(of audio: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: audio)
        return Double(file.length) / max(1, file.processingFormat.sampleRate)
    }

    /// The words of `results` as they come, reporting how far into the take they reach.
    private static func words<Results: AsyncSequence & Sendable>(
        of results: Results, language: CueLanguage?, length: TimeInterval, progress: (@Sendable (CaptionProgress) -> Void)?,
        text: @escaping @Sendable (Results.Element) -> AttributedString
    ) -> Task<[TimedWord], any Error> where Results.Element: Sendable {
        Task {
            var words: [TimedWord] = []
            for try await result in results {
                let heard = text(result)
                var resultWords: [TimedWord] = []
                for run in heard.runs {
                    guard let range = heard[run.range].audioTimeRange else { continue }
                    let text = String(heard[run.range].characters)
                    resultWords += spread(text, start: range.start.seconds, end: range.end.seconds, language: language)
                    if length > 0 { progress?(.transcribing(min(1, range.end.seconds / length))) }
                }
                words += SettledLastWord.applied(to: resultWords)
            }
            return words
        }
    }

    /// One pass of `modules` over the take, and what each `collecting` task (one per module, in order) read of it.
    private static func analyze(
        _ audio: URL, with modules: [any SpeechModule], terms: [String], collecting: [Task<[TimedWord], any Error>]
    ) async throws -> [[TimedWord]] {
        let file = try AVAudioFile(forReading: audio)
        let analyzer = SpeechAnalyzer(modules: modules)
        if !terms.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = terms
            // Only a hint: a model that ignores it still listens.
            try? await analyzer.setContext(context)
        }
        do {
            try await withTaskCancellationHandler {
                if let last = try await analyzer.analyzeSequence(from: file) {
                    try await analyzer.finalizeAndFinish(through: last)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
            } onCancel: {
                collecting.forEach { $0.cancel() }
                Task { await analyzer.cancelAndFinishNow() }
            }
            try Task.checkCancellation()
        } catch {
            collecting.forEach { $0.cancel() }
            throw error
        }
        var heard: [[TimedWord]] = []
        for collector in collecting {
            heard.append(try await collector.value)
        }
        return heard
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
