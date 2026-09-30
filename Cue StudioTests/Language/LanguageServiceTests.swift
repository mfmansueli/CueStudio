//
//  LanguageServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The three languages stay apart: none changes another, and each survives a relaunch.
@MainActor
@Suite("LanguageService")
struct LanguageServiceTests {
    private func makeService(
        defaults: TestDefaults, store: InMemoryAppLanguageStore = InMemoryAppLanguageStore(systemLocalization: "it", systemLanguages: ["it-IT"])
    ) -> LanguageService {
        LanguageService(defaults: defaults.defaults, store: store)
    }

    @Test func followsTheIPhoneUntilALanguageIsPicked() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        #expect(service.appLanguage == nil)
        #expect(service.interfaceLanguage == .italian)
        #expect(service.voiceFollowingLanguage == nil)
        #expect(service.scriptLanguage == nil)
    }

    @Test func anIPhoneLanguageCueDoesntHaveShowsEnglish() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults, store: InMemoryAppLanguageStore(systemLocalization: "ru", systemLanguages: ["ru-RU"]))
        #expect(service.interfaceLanguage == .english)
    }

    /// The core case: iPhone in Italian, Cue in English, a Portuguese script read in Portuguese.
    @Test func italianIPhoneEnglishCuePortugueseScriptAndVoice() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = InMemoryAppLanguageStore(systemLocalization: "it", systemLanguages: ["it-IT"])
        let service = makeService(defaults: defaults, store: store)
        service.setAppLanguage(.english)
        service.scriptLanguage = .portugueseBrazil
        service.voiceFollowingLanguage = .portugueseBrazil
        #expect(service.interfaceLanguage == .english)
        #expect(store.chosenLocalization == "en")
        #expect(store.systemLanguages == ["it-IT"])
        let script = TestData.script(text: "Oi, gente!", language: .portugueseBrazil)
        #expect(service.speechRequest(for: script) == .language(.portugueseBrazil))
    }

    @Test func changingTheAppLanguageChangesNothingElse() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.voiceFollowingLanguage = .portugueseBrazil
        service.scriptLanguage = .portugueseBrazil
        service.setAppLanguage(.japanese)
        #expect(service.interfaceLanguage == .japanese)
        #expect(service.voiceFollowingLanguage == .portugueseBrazil)
        #expect(service.scriptLanguage == .portugueseBrazil)
    }

    @Test func changingVoiceFollowingChangesNothingElse() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.setAppLanguage(.english)
        service.scriptLanguage = .portugueseBrazil
        service.voiceFollowingLanguage = .english
        #expect(service.interfaceLanguage == .english)
        #expect(service.appLanguage == .english)
        #expect(service.scriptLanguage == .portugueseBrazil)
    }

    @Test func changingTheScriptLanguageChangesNothingElse() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.setAppLanguage(.italian)
        service.voiceFollowingLanguage = .english
        service.scriptLanguage = .japanese
        #expect(service.interfaceLanguage == .italian)
        #expect(service.voiceFollowingLanguage == .english)
    }

    @Test func everyLanguageSurvivesARelaunch() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = InMemoryAppLanguageStore(systemLocalization: "it", systemLanguages: ["it-IT"])
        let first = makeService(defaults: defaults, store: store)
        first.setAppLanguage(.english)
        first.voiceFollowingLanguage = .portugueseBrazil
        first.scriptLanguage = .spanish
        let relaunched = makeService(defaults: defaults, store: store)
        #expect(relaunched.appLanguage == .english)
        #expect(relaunched.interfaceLanguage == .english)
        #expect(relaunched.voiceFollowingLanguage == .portugueseBrazil)
        #expect(relaunched.scriptLanguage == .spanish)
    }

    @Test func iPhoneLanguageForgetsThePick() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = InMemoryAppLanguageStore(systemLocalization: "it", systemLanguages: ["it-IT"])
        let service = makeService(defaults: defaults, store: store)
        service.setAppLanguage(.german)
        service.setAppLanguage(nil)
        #expect(store.chosenLocalization == nil)
        #expect(service.interfaceLanguage == .italian)
        #expect(service.systemInterfaceLanguage == .italian)
    }

    @Test func switchingTheInterfaceAppliesItOnce() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        var applied: [CueLanguage] = []
        let service = LanguageService(
            defaults: defaults.defaults,
            store: InMemoryAppLanguageStore(systemLocalization: "en", systemLanguages: ["en-US"]),
            apply: { applied.append($0) }
        )
        service.setAppLanguage(.arabic)
        service.setAppLanguage(.arabic)
        // English picked on an English iPhone shows the same interface: nothing to rebuild.
        service.setAppLanguage(nil)
        service.setAppLanguage(.english)
        #expect(applied == [.english, .arabic, .english])
    }

    /// The app language is never what Voice Following listens for.
    @Test func voiceFollowingNeverUsesTheAppLanguage() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.setAppLanguage(.japanese)
        let script = TestData.script(text: "Here are three habits that changed my mornings.")
        #expect(service.speechRequest(for: script) == .detect(text: script.text, systemLanguages: ["it-IT"]))
    }

    // MARK: - Captions and Clean Up

    /// Captions hear a take in the script's language, whatever Voice Following listens in.
    @Test func captionsListenInTheScriptsLanguage() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.setAppLanguage(.english)
        service.voiceFollowingLanguage = .english
        let script = TestData.script(text: "Oi, gente!", language: .portugueseBrazil)
        #expect(service.speechRequest(for: script) == .language(.english))
        #expect(service.captionRequest(for: script) == .language(.portugueseBrazil))
    }

    /// A script on Auto-detect is read from its text, as it always was.
    @Test func captionsOfAnAutoDetectScriptReadItsText() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.voiceFollowingLanguage = .japanese
        let script = TestData.script(text: "Here are three habits that changed my mornings.")
        #expect(service.captionRequest(for: script) == .detect(text: script.text, systemLanguages: ["it-IT"]))
    }

    /// A take without a script: the language new scripts start in, else the iPhone's.
    @Test func captionsOfAFreestyleTakeUseTheScriptLanguage() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.voiceFollowingLanguage = .english
        #expect(service.captionRequest(for: nil) == .detect(text: "", systemLanguages: ["it-IT"]))
        service.scriptLanguage = .spanish
        #expect(service.captionRequest(for: nil) == .language(.spanish))
    }

    /// Voice Following and captions never disagree silently.
    @Test func aDifferentVoiceFollowingLanguageIsAConflict() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        let portuguese = TestData.script(text: "Esses são três hábitos que mudaram as minhas manhãs.")
        #expect(service.languageConflict(for: portuguese) == nil)
        service.voiceFollowingLanguage = .portugueseBrazil
        #expect(service.languageConflict(for: portuguese) == nil)
        service.voiceFollowingLanguage = .english
        let conflict = service.languageConflict(for: portuguese)
        #expect(conflict == SpeechLanguageConflict(voiceFollowing: .english, captions: .portugueseBrazil))
        #expect(conflict?.message.contains(CueLanguage.portugueseBrazil.localizedName) == true)
        #expect(service.languageConflict(for: nil) == nil)
    }
}
