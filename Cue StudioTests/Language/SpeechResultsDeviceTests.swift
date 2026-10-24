//
//  SpeechResultsDeviceTests.swift
//  Cue StudioTests
//

import AVFAudio
import CoreMedia
import Foundation
import Speech
import Testing
@testable import Cue_Studio

/// What this device's two recognizers give for a recording, result by result: each result's stretch and text, and every
/// word's time, from the transcriber (what captions use where it runs) and from dictation. Nothing is judged; it is printed
/// (`SPEECH RESULTS`) to read against the recording, for the questions people's voices raised (LOCALIZATION.md §5): whether
/// dictation times Portuguese words closer to the voice than the transcriber, whose word starts come 0.12–0.3 s late in
/// fluent speech, and where a German reading's last word, heard twice ("wurde. wurde"), comes from. Opt-in and on a device
/// (`CUE_DEVICE=… scripts/test.sh device SpeechResultsDeviceTests`).
@Suite(
    "Speech results on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil),
    .timeLimit(.minutes(5))
)
@MainActor
struct SpeechResultsDeviceTests {
    @Test(arguments: ["human-pt-BR-1", "human-pt-BR-2", "human-pt-BR-3", "human-pt-BR-4", "human-de-DE-2", "human-de-DE-4"])
    func resultsOfBothRecognizers(name: String) async throws {
        KeepScreenAwake.enable()
        let sample = try #require(try SpeechSample.human().first { $0.name == name })
        let locale = Locale(identifier: sample.language.rawValue)
        await SpeechLocaleReservation.reserve(locale)
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
        let transcribed = try await Self.results(of: sample.url, with: transcriber, results: transcriber.results) { ($0.range, $0.text) }
        print("SPEECH RESULTS \(sample.label) transcriber:\n" + transcribed.joined(separator: "\n"))
        let dictation = DictationTranscriber(
            locale: locale, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange]
        )
        let dictated = try await Self.results(of: sample.url, with: dictation, results: dictation.results) { ($0.range, $0.text) }
        print("SPEECH RESULTS \(sample.label) dictation:\n" + dictated.joined(separator: "\n"))
        #expect(!transcribed.isEmpty || !dictated.isEmpty)
    }

    /// Every result of `module` for the recording at `url`: "[start–end] “text” · word@start–end …".
    private static func results<Results: AsyncSequence & Sendable>(
        of url: URL, with module: any SpeechModule, results: Results,
        reading: @escaping @Sendable (Results.Element) -> (CMTimeRange, AttributedString)
    ) async throws -> [String] where Results.Element: Sendable {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }
        let file = try AVAudioFile(forReading: url)
        let collector = Task {
            var lines: [String] = []
            for try await result in results {
                let (range, text) = reading(result)
                let words = text.runs.compactMap { run -> String? in
                    guard let time = text[run.range].audioTimeRange else { return nil }
                    return String(text[run.range].characters).trimmingCharacters(in: .whitespaces)
                        + String(format: "@%.2f–%.2f", time.start.seconds, time.end.seconds)
                }
                lines.append(String(format: "  [%.2f–%.2f] ", range.start.seconds, range.end.seconds)
                    + "“\(String(text.characters))” · " + words.joined(separator: " "))
            }
            return lines
        }
        let analyzer = SpeechAnalyzer(modules: [module])
        if let last = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collector.value
    }
}
