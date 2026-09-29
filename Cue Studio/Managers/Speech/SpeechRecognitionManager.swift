//
//  SpeechRecognitionManager.swift
//  Cue Studio
//

import AVFAudio
import Speech

/// Voice follow's ears: on-device transcription with the Speech framework (`SpeechAnalyzer`), in the
/// language Voice Following listens for (Profile › Language & Region, or the script's). Nothing
/// leaves the device and nothing is paid per use.
///
/// `SpeechTranscriber` recognizes every language it supports here, exactly as it always has;
/// `DictationTranscriber`, from the same framework, takes the languages (and devices) it doesn't.
/// The first time a language is used its model may need a download; until it's ready, Voice follow
/// falls back to the microphone level.
@MainActor
@Observable
final class SpeechRecognitionManager: SpeechTranscribing {
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    /// Bumped by every start and stop, so a start still waiting on a download backs out when
    /// something newer happened meanwhile.
    private var generation = 0

    private let resolver: SpeechLocaleResolver

    /// Characters of finalized text kept for matching; the tracker only looks at the last words.
    private nonisolated static let transcriptLimit = 400

    init(resolver: SpeechLocaleResolver = SpeechLocaleResolver()) {
        self.resolver = resolver
    }

    func start(script: String, language: SpeechLanguageRequest) async -> SpeechStartResult {
        stop()
        let current = generation
        let route: SpeechRoute
        switch await resolver.resolve(language, scriptText: script) {
        case .success(let resolved): route = resolved
        case .failure(let reason): return current == generation ? .unavailable(reason) : .cancelled
        }
        let module = Self.module(for: route)
        let modules: [any SpeechModule] = [module.speechModule]
        do {
            await Self.reserve(route.locale)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                do {
                    try await request.downloadAndInstall()
                } catch {
                    return current == generation ? .unavailable(.needsDownload(route.language)) : .cancelled
                }
            }
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
            guard current == generation else { return .cancelled }
            // Installed but unable to take audio: the model can't run here (the simulator).
            guard let format else { return .unavailable(.noRecognition) }
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
                return .cancelled
            }
            self.analyzer = analyzer
            self.input = input
            let transcripts = listen(to: module)
            let feed = AudioFeed(converter: AnalyzerInputConverter(analyzerFormat: format), input: input)
            return .listening(SpeechTranscription(audio: { feed.append($0) }, transcripts: transcripts), route)
        } catch {
            return current == generation ? .unavailable(.couldNotStart) : .cancelled
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

    // MARK: - Availability

    /// Whether Voice Following can follow the words in `language` here, and whether its model is
    /// already on the device.
    func availability(of language: CueLanguage) async -> VoiceFollowingAvailability {
        guard case .success(let route) = await resolver.resolve(.language(language)) else { return .unavailable }
        let modules = [Self.module(for: route).speechModule]
        switch await AssetInventory.status(forModules: modules) {
        case .installed:
            // Some devices list a model they can't run (the simulator): no audio format for it.
            return await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules) == nil ? .unavailable : .ready
        case .unsupported: return .unavailable
        default: return .downloadsOnFirstUse
        }
    }

    // MARK: - Recognizers

    /// The recognizer for a route, with Voice Following's options: words as they're being said
    /// (volatile), finalized quickly.
    private enum Module {
        case transcriber(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var speechModule: any SpeechModule {
            switch self {
            case .transcriber(let transcriber): transcriber
            case .dictation(let dictation): dictation
            }
        }
    }

    private static func module(for route: SpeechRoute) -> Module {
        switch route.engine {
        case .transcriber:
            .transcriber(SpeechTranscriber(
                locale: route.locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: []
            ))
        case .dictation:
            .dictation(DictationTranscriber(
                locale: route.locale,
                contentHints: [],
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .frequentFinalization],
                attributeOptions: []
            ))
        }
    }

    /// Finalized text plus the words still being recognized, as one running transcript.
    private func listen(to module: Module) -> AsyncStream<String> {
        let (transcripts, output) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(1))
        resultsTask = Task {
            var finalized = ""
            func heard(_ text: String, isFinal: Bool) {
                if isFinal {
                    finalized = String((finalized + " " + text).suffix(Self.transcriptLimit))
                    output.yield(finalized)
                } else {
                    output.yield(finalized + " " + text)
                }
            }
            do {
                switch module {
                case .transcriber(let transcriber):
                    for try await result in transcriber.results {
                        heard(String(result.text.characters), isFinal: result.isFinal)
                    }
                case .dictation(let dictation):
                    for try await result in dictation.results {
                        heard(String(result.text.characters), isFinal: result.isFinal)
                    }
                }
            } catch {
                // Cancelled or failed: the stream ends, and Voice follow falls back to the level.
            }
            output.finish()
        }
        return transcripts
    }

    // MARK: - Assets

    /// Keeps the language's model on the device. The system holds a few reserved languages at a
    /// time; when they're taken, the oldest other one makes room, so a new language still works.
    private static func reserve(_ locale: Locale) async {
        let reserved = await AssetInventory.reservedLocales
        guard !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else { return }
        if (try? await AssetInventory.reserve(locale: locale)) == true { return }
        if reserved.count >= AssetInventory.maximumReservedLocales, let oldest = reserved.first {
            await AssetInventory.release(reservedLocale: oldest)
            _ = try? await AssetInventory.reserve(locale: locale)
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
