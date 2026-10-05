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

    // MARK: - Dictation

    @Test func anIdeaIsHeardInTheScriptLanguageWhenOneIsSet() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.scriptLanguage = .portugueseBrazil
        // Even over a typed English idea: the script is what gets written in it.
        #expect(service.dictationRequest(existingText: "A video about my morning coffee") == .language(.portugueseBrazil))
        #expect(service.dictationRequest(existingText: "") == .language(.portugueseBrazil))
    }

    @Test func withoutAScriptLanguageTheTypedIdeaDecidesAndTheInterfaceIsTheFallback() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        // Nothing typed: the interface's language (Italian here), as the generated script would be.
        #expect(service.dictationRequest(existingText: "") == .language(.italian))
        #expect(service.dictationRequest(existingText: "  ") == .language(.italian))
        // Too little to tell a language from.
        #expect(service.dictationRequest(existingText: "café") == .language(.italian))
        // Enough typed: its language, whatever the interface is.
        let typed = "Esses são três hábitos que mudaram as minhas manhãs"
        #expect(service.dictationRequest(existingText: typed) == .detect(text: typed, systemLanguages: ["it-IT"]))
    }

    /// A language read from the typed idea keeps the creator's own regional variant (en-GB over en-US),
    /// the way captions and Voice Following already did: it goes through the same detection.
    @Test func aDetectedIdeaKeepsTheCreatorsRegionalVariant() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = InMemoryAppLanguageStore(systemLocalization: "en", systemLanguages: ["en-GB", "it-IT"])
        let service = makeService(defaults: defaults, store: store)
        let typed = "Here are three habits that changed my mornings"
        let request = service.dictationRequest(existingText: typed)
        #expect(request == .detect(text: typed, systemLanguages: ["en-GB", "it-IT"]))
        let catalog = FakeSpeechLocaleCatalog(transcriber: ["en-US", "en-GB"], dictation: ["en-US"])
        let route = try await SpeechLocaleResolver(catalog: catalog).resolve(request).get()
        #expect(route.locale.identifier(.bcp47) == "en-GB")
    }

    @Test func aChosenScriptLanguageIsNeverRefinedByTheIPhonesVariant() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = InMemoryAppLanguageStore(systemLocalization: "en", systemLanguages: ["en-GB"])
        let service = makeService(defaults: defaults, store: store)
        service.scriptLanguage = .english
        #expect(service.dictationRequest(existingText: "Here are three habits that changed my mornings") == .language(.english))
        let catalog = FakeSpeechLocaleCatalog(transcriber: ["en-US", "en-GB"])
        let route = try await SpeechLocaleResolver(catalog: catalog).resolve(.language(.english)).get()
        #expect(route.locale.identifier(.bcp47) == "en-US")
    }

    @Test func voiceFollowingsLanguageNeverDecidesWhatAnIdeaIsHeardIn() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults)
        service.voiceFollowingLanguage = .japanese
        #expect(service.dictationRequest(existingText: "") == .language(.italian))
    }
}
