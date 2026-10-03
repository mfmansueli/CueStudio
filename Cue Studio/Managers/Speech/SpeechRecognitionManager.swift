//
//  SpeechRecognitionManager.swift
//  Cue Studio
//

import AVFAudio
import NaturalLanguage
import Speech

/// Voice follow's ears: on-device transcription with the Speech framework (`SpeechAnalyzer`), in
/// the language Voice Following asks for (see `SpeechLanguageRequest`). Nothing leaves the device
/// and nothing is paid per minute. The first time a language is used its model may need a download;
/// until it's ready, Voice follow falls back to the microphone level.
///
/// `SpeechTranscriber` is the engine, as it always was. Languages it doesn't cover on this device
/// fall back to `DictationTranscriber`, the same framework's on-device dictation model, so more
/// languages can follow a reading without another service.
@MainActor
@Observable
final class SpeechRecognitionManager: SpeechTranscribing {
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    /// Bumped by every start and stop, so a start still waiting on a download backs out when
    /// something newer happened meanwhile.
    private var generation = 0

    /// Characters of finalized text kept for matching; the tracker only looks at the last words.
    private static let transcriptLimit = 400

    func start(script: String, language: SpeechLanguageRequest) async -> SpeechTranscription? {
        stop()
        let current = generation
        guard let resolved = await Self.engine(for: language, script: script) else { return nil }
        let (engine, locale) = resolved
        let modules: [any SpeechModule] = [engine.module]
        do {
            if await !AssetInventory.reservedLocales.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
                _ = try? await AssetInventory.reserve(locale: locale)
            }
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await request.downloadAndInstall()
            }
            guard current == generation,
                  let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) else { return nil }
            let analyzer = SpeechAnalyzer(modules: modules, options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse))
            let context = AnalysisContext()
            context.contextualStrings[.general] = Self.vocabulary(in: script)
            try? await analyzer.setContext(context)
            try await analyzer.prepareToAnalyze(in: format)
            let (inputs, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
            try await analyzer.start(inputSequence: inputs)
            guard current == generation else {
                input.finish()
                await analyzer.cancelAndFinishNow()
                return nil
            }
            self.analyzer = analyzer
            self.input = input
            let transcripts = switch engine {
            case .speech(let transcriber): listen(to: transcriber)
            case .dictation(let transcriber): listen(to: transcriber)
            }
            let feed = AudioFeed(converter: AnalyzerInputConverter(analyzerFormat: format), input: input)
            return SpeechTranscription(audio: { feed.append($0) }, transcripts: transcripts)
        } catch {
            return nil
        }
    }

    func stop() {
        generation += 1
        input?.finish()
        input = nil
        resultsTask?.cancel()
        resultsTask = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
    }

    /// Finalized text plus the words still being recognized, as one running transcript.
    private func listen(to transcriber: SpeechTranscriber) -> AsyncStream<String> {
        let (transcripts, output) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        resultsTask = Task {
            var finalized = ""
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finalized = String((finalized + " " + text).suffix(Self.transcriptLimit))
                        output.yield(finalized)
                    } else {
                        output.yield(finalized + " " + text)
                    }
                }
            } catch {
                // Cancelled or failed: the stream ends, and Voice follow falls back to the level.
            }
            output.finish()
        }
        return transcripts
    }

    /// The same running transcript from the dictation model (languages `SpeechTranscriber` lacks).
    private func listen(to transcriber: DictationTranscriber) -> AsyncStream<String> {
        let (transcripts, output) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        resultsTask = Task {
            var finalized = ""
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finalized = String((finalized + " " + text).suffix(Self.transcriptLimit))
                        output.yield(finalized)
                    } else {
                        output.yield(finalized + " " + text)
                    }
                }
            } catch {
                // Cancelled or failed: the stream ends, and Voice follow falls back to the level.
            }
            output.finish()
        }
        return transcripts
    }

    // MARK: - Language

    /// The recognizer for a request: `SpeechTranscriber` in the first locale it supports, else the
    /// dictation model in the first one it supports. Nil when this device can't listen in it.
    private static func engine(for request: SpeechLanguageRequest, script: String) async -> (Engine, Locale)? {
        let candidates = SpeechLocaleResolver.candidates(
            for: request,
            detectedLanguageCode: request == .detectFromScript ? SpeechLocaleResolver.detectedLanguageCode(in: script) : nil
        )
        if SpeechTranscriber.isAvailable, let locale = await speechTranscriberLocale(among: candidates) {
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: []
            )
            return (.speech(transcriber), locale)
        }
        if let locale = await dictationLocale(among: candidates) {
            let transcriber = DictationTranscriber(
                locale: locale,
                contentHints: [],
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .frequentFinalization],
                attributeOptions: []
            )
            return (.dictation(transcriber), locale)
        }
        return nil
    }

    /// The script's language, in the creator's own region when they use it (pt-BR over pt-PT).
    /// Without a clear language, the device's. Nil when the language isn't supported. Captions use
    /// it for takes of a script without a language of its own.
    static func locale(for script: String) async -> Locale? {
        await locale(for: .detectFromScript, script: script)
    }

    /// The `SpeechTranscriber` locale for a request (captions need its word timings).
    static func locale(for request: SpeechLanguageRequest, script: String) async -> Locale? {
        let candidates = SpeechLocaleResolver.candidates(
            for: request,
            detectedLanguageCode: request == .detectFromScript ? SpeechLocaleResolver.detectedLanguageCode(in: script) : nil
        )
        return await speechTranscriberLocale(among: candidates)
    }

    /// Whether Voice Following can listen in `language` on this device, asked of the framework.
    func availability(of language: CueLanguage) async -> SpeechLanguageAvailability {
        let candidates = SpeechLocaleResolver.candidates(for: .language(language), detectedLanguageCode: nil)
        var modules: [any SpeechModule] = []
        if SpeechTranscriber.isAvailable, let locale = await Self.speechTranscriberLocale(among: candidates) {
            modules = [SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])]
        } else if let locale = await Self.dictationLocale(among: candidates) {
            modules = [DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [])]
        }
        guard !modules.isEmpty else { return .unavailable }
        switch await AssetInventory.status(forModules: modules) {
        case .installed: return .ready
        case .supported, .downloading: return .downloadable
        case .unsupported: return .unavailable
        @unknown default: return .downloadable
        }
    }

    private static func speechTranscriberLocale(among candidates: [Locale]) async -> Locale? {
        for candidate in candidates {
            if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return supported
            }
        }
        return nil
    }

    private static func dictationLocale(among candidates: [Locale]) async -> Locale? {
        for candidate in candidates {
            if let supported = await DictationTranscriber.supportedLocale(equivalentTo: candidate) {
                return supported
            }
        }
        return nil
    }

    /// Which of the framework's transcribers a recognition runs on.
    private enum Engine {
        case speech(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var module: any SpeechModule {
            switch self {
            case .speech(let transcriber): transcriber
            case .dictation(let transcriber): transcriber
            }
        }
    }

    /// Names, brands and numbers a general model may not expect, as recognition hints.
    private static func vocabulary(in script: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for word in CueParser.stripCues(script).split(whereSeparator: \.isWhitespace) {
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            guard trimmed.count >= 3,
                  trimmed.first?.isUppercase == true || trimmed.contains(where: \.isNumber),
                  seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
            if result.count == 100 { break }
        }
        return result
    }

    // MARK: - Audio

    /// Converts microphone buffers to the analyzer's format on the audio thread.
    private nonisolated final class AudioFeed: Sendable {
        private let lock = NSLock()
        // Only touched while holding `lock`. A `Mutex` can't hold it: converting ties each
        // caller's buffer to the converter, which region checking rejects.
        private nonisolated(unsafe) let converter: AnalyzerInputConverter
        private let input: AsyncStream<AnalyzerInput>.Continuation

        init(converter: AnalyzerInputConverter, input: AsyncStream<AnalyzerInput>.Continuation) {
            self.converter = converter
            self.input = input
        }

        func append(_ buffer: AVAudioPCMBuffer) {
            let converted = lock.withLock {
                (try? converter.convert(buffer, at: nil)) ?? []
            }
            for item in converted {
                input.yield(item)
            }
        }
    }
}
