//
//  SpeechLanguageRequestTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("SpeechLanguageRequest")
struct SpeechLanguageRequestTests {
    @Test func theVoiceFollowingLanguageWins() {
        let request = SpeechLanguageRequest(voiceFollowing: .english, scriptLanguage: .portugueseBrazil, scriptText: "Oi", systemLanguages: [])
        #expect(request == .language(.english))
    }

    @Test func sameAsScriptUsesTheScriptsLanguage() {
        let request = SpeechLanguageRequest(voiceFollowing: nil, scriptLanguage: .portugueseBrazil, scriptText: "Hello", systemLanguages: [])
        #expect(request == .language(.portugueseBrazil))
    }

    @Test func aScriptOnAutoDetectIsReadFromItsText() {
        let request = SpeechLanguageRequest(voiceFollowing: nil, scriptLanguage: nil, scriptText: "Olá", systemLanguages: ["pt-PT"])
        #expect(request == .detect(text: "Olá", systemLanguages: ["pt-PT"]))
    }
}
