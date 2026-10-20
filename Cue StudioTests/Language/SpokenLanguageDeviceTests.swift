//
//  SpokenLanguageDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Speech
import Testing
@testable import Cue_Studio

/// Which language a take without a script is spoken in, on this device's own recognizers: each language's recording
/// (`Fixtures/Speech`, Apple's system voices) is compared among the languages an iPhone in Portuguese would try (Portuguese, English,
/// Spanish) and its own, starting from a wrong one, and has to be found. A language only dictation hears on this device (it doesn't
/// rate its words) is *not validated*, never passed. Opt-in, like `CaptionSpeechTests` (`TEST_RUNNER_CUE_SPEECH_E2E=1`).
@Suite(
    "Spoken language on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_SPEECH_E2E"] != nil)
)
struct SpokenLanguageDeviceTests {
    private final class BundleToken {}

    /// Says what each language scored, for the report.
    private struct Reporting: SpokenLanguageListening {
        let inner = TranscriberLanguageListener()

        func score(of clip: URL, in language: CueLanguage, mayDownload: Bool) async throws -> SpokenLanguageScore? {
            do {
                let score = try await inner.score(of: clip, in: language, mayDownload: mayDownload)
                print("SPOKEN   \(language.rawValue): " + (score.map { String(format: "%.2f · %d words", $0.confidence, $0.words) } ?? "not judged"))
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
        let audio = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-\(language.rawValue)", withExtension: "m4a"))
        // Start from a language that isn't the one spoken, as a take without a script on an iPhone in another language would.
        let first: CueLanguage = language == .portugueseBrazil ? .english : .portugueseBrazil
        var candidates = [first, .portugueseBrazil, .english, .spanish, language]
        var seen = Set<CueLanguage>()
        candidates = candidates.filter { seen.insert($0).inserted }
        // The language spoken is on this device, as on an iPhone set to it.
        let modules: [any SpeechModule] = [SpeechTranscriber(locale: route.locale, preset: .transcription)]
        await SpeechLocaleReservation.reserve(route.locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) { try await request.downloadAndInstall() }
        let started = ContinuousClock.now
        let found = try await SpokenLanguageIdentifier(listener: Reporting()).spokenLanguage(in: audio, among: candidates)
        let took = (ContinuousClock.now - started) / .seconds(1)
        print("SPOKEN \(language.rawValue): found \(found?.rawValue ?? "nothing") among \(candidates.map(\.rawValue)) in \(String(format: "%.1f", took)) s")
        #expect(found == language)
    }
}
