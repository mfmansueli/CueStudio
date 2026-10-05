//
//  SpeechFixtureCoverageTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// The speech tests that run on a device (`VoiceFollowingSpeechTests`, `CaptionSpeechTests`) go through
/// every language Cue offers. This one runs everywhere and keeps them honest: each of the 20 has a
/// script and a recording, the script is in the language it claims, and the recording is long enough
/// to hold it. A language added to Cue without them fails here, before a device is needed.
@MainActor
@Suite("Speech fixtures")
struct SpeechFixtureCoverageTests {
    private final class BundleToken {}

    @Test func everyLanguageHasAScript() {
        #expect(Set(VoiceFollowingSpeechTests.scripts.keys) == Set(CueLanguage.allCases))
    }

    @Test(arguments: CueLanguage.allCases)
    func everyLanguageHasARecordingOfItsScript(language: CueLanguage) throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-\(language.rawValue)", withExtension: "m4a"))
        let file = try AVAudioFile(forReading: url)
        let seconds = Double(file.length) / file.processingFormat.sampleRate
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let words = ScriptWords(text: script, language: language).count
        #expect(seconds > 5, "\(language.rawValue): \(seconds) s")
        // Speech runs about one to five words a second (a written-without-spaces language more).
        #expect(Double(words) / seconds > 0.8 && Double(words) / seconds < 12, "\(language.rawValue): \(words) words in \(seconds) s")
    }

    @Test(arguments: CueLanguage.allCases)
    func theScriptIsInTheLanguageItClaims(language: CueLanguage) throws {
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let detected = LanguageDetector.language(in: script)
        #expect(detected == language, "\(language.rawValue) detected as \(detected?.rawValue ?? "nothing")")
        // Written in the script of the language: Devanagari for Hindi, Traditional characters for zh-TW.
        if language == .hindi {
            #expect(script.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) })
        }
    }

    @Test(arguments: CueLanguage.allCases)
    func theScriptCanBeFollowed(language: CueLanguage) throws {
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let words = ScriptWords(text: script, language: language)
        #expect(words.count >= 12)
        // Read word by word without error, the tracker reaches the end (the recognizer's own mistakes aside).
        var tracker = ScriptSpeechTracker(words: words.tokens, language: language)
        var heard: [String] = []
        for token in words.tokens {
            heard.append(token)
            tracker.hear(language.writesWithoutSpaces ? heard.suffix(40).joined() : heard.suffix(40).joined(separator: " "))
        }
        #expect(tracker.position >= words.count - 1, "\(language.rawValue): \(tracker.position)/\(words.count)")
    }
}
