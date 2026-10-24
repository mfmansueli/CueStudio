//
//  SpokenLanguageDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Speech
import Testing
@testable import Cue_Studio

/// Which language a take without a script is spoken in, on this device's own recognizers: each recording of the run's voice
/// (`SpeechSample`: Apple's system voice, or four people reading FLEURS sentences) is compared among the languages an iPhone
/// in Portuguese would try (Portuguese, English, Spanish) and its own, starting from a wrong one, and has to be found. A
/// language only dictation hears on this device (it doesn't rate its words) is *not validated*, never passed. Opt-in, like
/// `CaptionSpeechTests` (`TEST_RUNNER_CUE_SPEECH_E2E=1`).
@Suite(
    "Spoken language on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil)
)
struct SpokenLanguageDeviceTests {
    /// Says what each language scored, for the report.
    private struct Reporting: SpokenLanguageListening {
        let inner = TranscriberLanguageListener()

        func score(of clip: URL, in language: CueLanguage, mayDownload: Bool) async throws -> SpokenLanguageScore? {
            do {
                let score = try await inner.score(of: clip, in: language, mayDownload: mayDownload)
                let written = score.map { " · written in \($0.writtenIn?.rawValue ?? "?")" } ?? ""
                print("SPOKEN   \(language.rawValue): " + (score.map { String(format: "%.2f · %d words", $0.confidence, $0.words) } ?? "not judged") + written)
                return score
            } catch {
                print("SPOKEN   \(language.rawValue): failed · \(error.localizedDescription)")
                throw error
            }
        }
    }

    @Test(arguments: CueLanguage.allCases)
    func theLanguageSpokenIsFound(language: CueLanguage) async throws {
        await KeepScreenAwake.enable()
        guard case .success(let route) = await SpeechLocaleResolver().resolve(.language(language)), route.engine == .transcriber else {
            try Test.cancel("\(language.rawValue) not validated: only dictation hears it on this device, and dictation doesn't rate its words")
        }
        // Start from a language that isn't the one spoken, as a take without a script on an iPhone in another language would.
        let first: CueLanguage = language == .portugueseBrazil ? .english : .portugueseBrazil
        var candidates = [first, .portugueseBrazil, .english, .spanish, language]
        var seen = Set<CueLanguage>()
        candidates = candidates.filter { seen.insert($0).inserted }
        // The language spoken is on this device, as on an iPhone set to it (its place taken as the identifier takes the
        // candidates', so taking it never releases one of them).
        let modules: [any SpeechModule] = [SpeechTranscriber(locale: route.locale, preset: .transcription)]
        SpeechLocaleReservation.willUse(candidates.map(\.locale))
        await SpeechLocaleReservation.reserve(route.locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) { try await request.downloadAndInstall() }
        for sample in try SpeechSample.samples(of: language) {
            let started = ContinuousClock.now
            let found = try await SpokenLanguageIdentifier(listener: Reporting()).spokenLanguage(in: sample.url, among: candidates)
            let took = (ContinuousClock.now - started) / .seconds(1)
            print(
                "SPOKEN \(language.rawValue) \(sample.label): found \(found?.rawValue ?? "nothing") among \(candidates.map(\.rawValue))"
                    + " in \(String(format: "%.1f", took)) s"
            )
            #expect(found == language, "\(sample.label) heard as \(found?.rawValue ?? "nothing")")
        }
    }
}
