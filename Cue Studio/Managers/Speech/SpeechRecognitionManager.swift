//
//  SpeechRecognitionManager.swift
//  Cue Studio
//

import AVFAudio
import NaturalLanguage
import Speech

/// Voice follow's ears: on-device transcription with the Speech framework (`SpeechAnalyzer`), in
/// the script's language. Nothing leaves the device. The first time a language is used its model
/// may need a download; until it's ready, Voice follow falls back to the microphone level.
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

    func start(script: String) async -> SpeechTranscription? {
        stop()
        let current = generation
        guard SpeechTranscriber.isAvailable, let locale = await Self.locale(for: script) else { return nil }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
        let modules: [any SpeechModule] = [transcriber]
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
            let transcripts = listen(to: transcriber)
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

    // MARK: - Language

    /// The script's language, in the creator's own region when they use it (pt-BR over pt-PT).
    /// Without a clear language, the device's. Nil when the language isn't supported.
    static func locale(for script: String) async -> Locale? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(CueParser.stripCues(script))
        var candidates: [Locale] = []
        if let language = recognizer.dominantLanguage {
            let code = Locale.Language(identifier: language.rawValue).languageCode
            candidates += Locale.preferredLanguages
                .map { Locale(identifier: $0) }
                .filter { $0.language.languageCode == code }
            candidates.append(Locale(identifier: language.rawValue))
        } else {
            candidates.append(.current)
        }
        for candidate in candidates {
            if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: candidate) {
                return supported
            }
        }
        return nil
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
