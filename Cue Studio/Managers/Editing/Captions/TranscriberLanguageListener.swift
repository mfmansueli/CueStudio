//
//  TranscriberLanguageListener.swift
//  Cue Studio
//

import AVFoundation
import Speech

/// Rates a language on `SpeechTranscriber`'s own confidence in each word. Measured on an iPhone 15 Pro (10 s of eight languages'
/// recordings and three real takes, each heard in three or four languages): the language spoken scored 0.87–1.00, the others
/// 0.02–0.95 (English heard as Spanish was the closest), in 0.2–1.3 s a language. The dictation model of iPhones and iPads without
/// `SpeechTranscriber` gives no confidence for some results and times them at half their moment (measured on an iPad Pro, A12Z), so it
/// is never used to judge: there the language stays the one asked for.
nonisolated struct TranscriberLanguageListener: SpokenLanguageListening {
    var resolver = SpeechLocaleResolver()

    func score(of clip: URL, in language: CueLanguage, mayDownload: Bool) async throws -> SpokenLanguageScore? {
        guard case .success(let route) = await resolver.resolve(.language(language)), route.engine == .transcriber else { return nil }
        let transcriber = SpeechTranscriber(
            locale: route.locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.transcriptionConfidence]
        )
        let modules: [any SpeechModule] = [transcriber]
        // The system holds only a few languages at a time: take a place before asking for the model (a model on the iPhone reads
        // as not installed while it has no place).
        await SpeechLocaleReservation.reserve(route.locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            // A language that isn't on the iPhone isn't worth a download just to compare.
            guard mayDownload else { return nil }
            try await request.downloadAndInstall()
        }
        try Task.checkCancellation()
        let collector = Task {
            var confidences: [Double] = []
            for try await result in transcriber.results {
                for run in result.text.runs where !String(result.text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let confidence = run.transcriptionConfidence { confidences.append(confidence) }
                }
            }
            return confidences
        }
        let analyzer = SpeechAnalyzer(modules: modules)
        try await withTaskCancellationHandler {
            if let last = try await analyzer.analyzeSequence(from: try AVAudioFile(forReading: clip)) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } onCancel: {
            collector.cancel()
            Task { await analyzer.cancelAndFinishNow() }
        }
        try Task.checkCancellation()
        let confidences = try await collector.value
        guard !confidences.isEmpty else { return SpokenLanguageScore(confidence: 0, words: 0) }
        return SpokenLanguageScore(confidence: confidences.reduce(0, +) / Double(confidences.count), words: confidences.count)
    }
}
