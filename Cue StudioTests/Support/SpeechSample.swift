//
//  SpeechSample.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A recording the device speech suites play and the script it reads. Two kinds of voice: Apple's system voice reading the
/// language's own script (`Fixtures/Speech/speech-<language>.m4a`, `VoiceFollowingSpeechTests.scripts`), and people reading a
/// sentence from Google's FLEURS (`Fixtures/Speech/Human`, listed in `human-speech.json` with the dataset's credit: four a
/// language, two women and two men, CC BY 4.0). `TEST_RUNNER_CUE_SPEECH_VOICE` picks what a run plays: `synthetic` (the
/// default), `human` or `both`.
///
/// The system voices say the recognizers and timings work; people say how well they hear real voices, accents and pace. FLEURS
/// is read speech, so it still isn't a creator talking freely, with music or in the street.
struct SpeechSample: Sendable, CustomTestStringConvertible {
    enum Voice: String, Sendable {
        case synthetic, human
    }

    let language: CueLanguage
    /// The recording's name in the test bundle, which also names it in the report.
    let name: String
    let script: String
    let voice: Voice
    /// Who reads it, for a person ("female", "male").
    let speaker: String?
    /// What isn't an exact match for the language (FLEURS has Latin American Spanish for es-ES, …).
    let note: String?
    let url: URL

    var testDescription: String { name }

    /// How the report names it: "human-pt-BR-1 (male)".
    var label: String { speaker.map { "\(name) (\($0))" } ?? name }

    private final class BundleToken {}

    private static var bundle: Bundle { Bundle(for: BundleToken.self) }

    /// The voices this run plays.
    static var voices: [Voice] {
        switch ProcessInfo.processInfo.environment["CUE_SPEECH_VOICE"] {
        case "human": [.human]
        case "both": [.synthetic, .human]
        default: [.synthetic]
        }
    }

    /// The languages this run plays: `TEST_RUNNER_CUE_SPEECH_LANGUAGES=ko-KR,pt-BR` for a few, all of them otherwise.
    static func isPlayed(_ language: CueLanguage) -> Bool {
        guard let listed = ProcessInfo.processInfo.environment["CUE_SPEECH_LANGUAGES"], !listed.isEmpty else { return true }
        return listed.split(separator: ",").contains { $0.trimmingCharacters(in: .whitespaces) == language.rawValue }
    }

    /// What this run plays in `language`.
    static func samples(of language: CueLanguage) throws -> [SpeechSample] {
        guard isPlayed(language) else { return [] }
        return try voices.flatMap { voice in
            switch voice {
            case .synthetic: [try synthetic(of: language)]
            case .human: try human().filter { $0.language == language }
            }
        }
    }

    /// The system voice reading the language's script.
    static func synthetic(of language: CueLanguage) throws -> SpeechSample {
        let name = "speech-\(language.rawValue)"
        let script = try #require(VoiceFollowingSpeechTests.scripts[language], "\(language.rawValue) has no script")
        let url = try #require(bundle.url(forResource: name, withExtension: "m4a"), "\(language.rawValue) has no recording")
        return SpeechSample(language: language, name: name, script: script, voice: .synthetic, speaker: nil, note: nil, url: url)
    }

    /// Every FLEURS reading, in the manifest's order.
    static func human() throws -> [SpeechSample] {
        let listed = try #require(bundle.url(forResource: "human-speech", withExtension: "json"), "the human speech manifest is missing")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: listed))
        return try manifest.samples.map { entry in
            let language = try #require(CueLanguage(rawValue: entry.language), "\(entry.language) isn't a Cue language")
            let url = try #require(bundle.url(forResource: entry.file, withExtension: "m4a"), "\(entry.file) is missing")
            return SpeechSample(
                language: language, name: entry.file, script: entry.script, voice: .human, speaker: entry.voice, note: entry.note, url: url
            )
        }
    }

    private struct Manifest: Decodable {
        let samples: [ManifestEntry]
    }

    private struct ManifestEntry: Decodable {
        let language: String
        let file: String
        let script: String
        let voice: String
        let note: String?
    }
}
