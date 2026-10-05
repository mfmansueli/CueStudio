//
//  SpeechLocaleResolverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("SpeechLocaleResolver")
struct SpeechLocaleResolverTests {
    /// An iPhone whose `SpeechTranscriber` has the big languages and whose dictation model has the
    /// rest, like the ones Cue runs on.
    private let device = FakeSpeechLocaleCatalog(
        transcriber: ["en-US", "en-GB", "es-ES", "pt-BR", "fr-FR", "de-DE", "it-IT", "ja-JP", "ko-KR", "zh-CN"],
        dictation: ["en-US", "pt-BR", "pt-PT", "hi-IN", "id-ID", "ar-SA", "tr-TR", "th-TH", "vi-VN", "zh-CN"],
        defaults: ["pt": "pt-PT", "en": "en-US"]
    )

    private func route(_ request: SpeechLanguageRequest, on catalog: FakeSpeechLocaleCatalog? = nil) async -> Result<SpeechRoute, SpeechUnavailableReason> {
        await SpeechLocaleResolver(catalog: catalog ?? device).resolve(request)
    }

    // MARK: - English and Portuguese: the original recognizer, as before

    @Test func englishUsesTheOriginalRecognizer() async throws {
        let route = try await route(.language(.english)).get()
        #expect(route == SpeechRoute(engine: .transcriber, locale: Locale(identifier: "en-US"), language: .english))
    }

    @Test func portugueseUsesTheOriginalRecognizerInBrazilianPortuguese() async throws {
        let route = try await route(.language(.portugueseBrazil)).get()
        #expect(route == SpeechRoute(engine: .transcriber, locale: Locale(identifier: "pt-BR"), language: .portugueseBrazil))
    }

    @Test func anEnglishScriptOnAutoDetectIsHeardAsBefore() async throws {
        let text = "Here are three habits that changed my mornings. First, I drink a glass of water."
        let route = try await route(.detect(text: text, systemLanguages: ["en-US"])).get()
        #expect(route.engine == .transcriber)
        #expect(route.locale.identifier(.bcp47) == "en-US")
    }

    @Test func aPortugueseScriptOnAutoDetectIsHeardInBrazilianPortuguese() async throws {
        let text = "Esses são três hábitos que mudaram as minhas manhãs. Primeiro, eu bebo um copo de água."
        // Cue in English on an Italian iPhone: no Portuguese among the iPhone's languages.
        let route = try await route(.detect(text: text, systemLanguages: ["it-IT", "en-US"])).get()
        #expect(route == SpeechRoute(engine: .transcriber, locale: Locale(identifier: "pt-BR"), language: .portugueseBrazil))
    }

    @Test func aDetectedLanguageKeepsTheCreatorsRegion() async throws {
        let text = "Here are three habits that changed my mornings. First, I drink a glass of water."
        let route = try await route(.detect(text: text, systemLanguages: ["en-GB", "it-IT"])).get()
        #expect(route.locale.identifier(.bcp47) == "en-GB")
    }

    // MARK: - More languages

    @Test func languagesTheOriginalRecognizerLacksUseDictation() async throws {
        for language in [CueLanguage.hindi, .indonesian, .arabic, .turkish, .thai, .vietnamese] {
            let route = try await route(.language(language)).get()
            #expect(route.engine == .dictation)
            #expect(route.locale == language.speechLocale)
            #expect(route.language == language)
        }
    }

    @Test func withoutTheOriginalRecognizerEverythingUsesDictation() async throws {
        let simulator = FakeSpeechLocaleCatalog(dictation: CueLanguage.allCases.map(\.rawValue))
        for language in CueLanguage.allCases {
            let route = try await route(.language(language), on: simulator).get()
            #expect(route.engine == .dictation)
            #expect(route.locale == language.speechLocale)
        }
    }

    // MARK: - Hindi

    /// `SpeechTranscriber` writes Hindi in Latin letters: a script in Devanagari is heard by the
    /// dictation model, which writes Devanagari; a Hinglish script by `SpeechTranscriber`.
    @Test func hindiIsHeardInTheScriptsLetters() async throws {
        let both = FakeSpeechLocaleCatalog(transcriber: ["hi-IN"], dictation: ["hi-IN"])
        let resolver = SpeechLocaleResolver(catalog: both)
        let devanagari = try await resolver.resolve(.language(.hindi), scriptText: "ये तीन आदतें हैं").get()
        #expect(devanagari.engine == .dictation)
        let latin = try await resolver.resolve(.language(.hindi), scriptText: "Ye teen aadatein hain").get()
        #expect(latin.engine == .transcriber)
        let detected = try await resolver.resolve(.detect(text: "ये तीन आदतें हैं जिन्होंने मेरी सुबह बदल दी।", systemLanguages: [])).get()
        #expect(detected.engine == .dictation)
    }

    @Test func otherLanguagesTryTheOriginalRecognizerFirst() {
        for language in CueLanguage.allCases where language != .hindi {
            #expect(SpeechLocaleResolver.engines(for: language, scriptText: "x") == [.transcriber, .dictation])
        }
    }

    // MARK: - Never another language

    @Test func anUnsupportedLanguageIsUnavailableNotReplaced() async {
        let englishOnly = FakeSpeechLocaleCatalog(transcriber: ["en-US"], dictation: ["en-US"])
        let result = await route(.language(.thai), on: englishOnly)
        #expect(result == .failure(.unsupported(.thai)))
    }

    @Test func brazilianPortugueseIsNeverHeardAsEuropeanPortuguese() async {
        let european = FakeSpeechLocaleCatalog(dictation: ["pt-PT"], defaults: ["pt-BR": "pt-PT"])
        let result = await route(.language(.portugueseBrazil), on: european)
        #expect(result == .failure(.unsupported(.portugueseBrazil)))
    }

    @Test func aScriptWithoutWordsHasNoLanguage() async {
        let result = await route(.detect(text: "[pause] 123 — !", systemLanguages: ["en-US"]))
        #expect(result == .failure(.unknownLanguage))
    }

    @Test func aFreestyleTakeListensInTheIPhonesLanguage() async throws {
        let route = try await route(.detect(text: "", systemLanguages: ["pt-BR", "en-US"])).get()
        #expect(route.locale.identifier(.bcp47) == "pt-BR")
    }

    @Test func noRecognitionAtAll() async {
        let result = await route(.language(.english), on: FakeSpeechLocaleCatalog())
        #expect(result == .failure(.noRecognition))
    }

    // MARK: - Chinese: two writing systems

    private let chineseDevice = FakeSpeechLocaleCatalog(
        transcriber: ["zh-CN", "zh-TW", "zh-HK", "en-US"],
        dictation: ["zh-CN", "zh-TW", "zh-HK"],
        defaults: ["zh": "zh-CN"]
    )

    @Test func aTraditionalScriptOnAutoDetectIsHeardInTaiwanChineseNeverSimplified() async throws {
        let text = "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。"
        let route = try await route(.detect(text: text, systemLanguages: ["en-US"]), on: chineseDevice).get()
        #expect(route.locale.identifier(.bcp47) == "zh-TW")
        #expect(route.language == .chineseTraditional)
    }

    @Test func aSimplifiedScriptOnAutoDetectIsHeardInSimplified() async throws {
        let text = "这是改变我早晨的三个习惯。第一，我在看手机之前先喝一杯水。"
        let route = try await route(.detect(text: text, systemLanguages: ["en-US"]), on: chineseDevice).get()
        #expect(route.locale.identifier(.bcp47) == "zh-CN")
        #expect(route.language == .chineseSimplified)
    }

    @Test func theCreatorsOwnChineseVariantIsKeptInTheScriptsWritingSystem() async throws {
        let text = "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。"
        // A Simplified-Chinese iPhone doesn't pull Traditional text into Simplified recognition; a Hong Kong one is kept.
        let simplifiedPhone = try await route(.detect(text: text, systemLanguages: ["zh-Hans-CN"]), on: chineseDevice).get()
        #expect(simplifiedPhone.locale.identifier(.bcp47) == "zh-TW")
        let hongKongPhone = try await route(.detect(text: text, systemLanguages: ["zh-Hant-HK"]), on: chineseDevice).get()
        #expect(hongKongPhone.locale.identifier(.bcp47) == "zh-HK")
    }

    @Test func traditionalChineseIsUnavailableNotReplacedBySimplified() async {
        let simplifiedOnly = FakeSpeechLocaleCatalog(transcriber: ["zh-CN"], dictation: ["zh-CN"], defaults: ["zh": "zh-CN", "zh-TW": "zh-CN"])
        let explicit = await route(.language(.chineseTraditional), on: simplifiedOnly)
        #expect(explicit == .failure(.unsupported(.chineseTraditional)))
        let text = "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。"
        let detected = await route(.detect(text: text, systemLanguages: []), on: simplifiedOnly)
        guard case .failure(.unsupportedDetected) = detected else {
            Issue.record("A Traditional script was heard as Simplified: \(detected)")
            return
        }
    }

    // MARK: - Explicit choices stay as picked

    @Test func anExplicitLanguageIsNotRefinedByTheIPhonesVariant() async throws {
        // The creator picked English; an iPhone in British English doesn't change what was picked (en-US).
        let route = try await route(.language(.english)).get()
        #expect(route.locale.identifier(.bcp47) == "en-US")
    }

    @Test func aDetectedPortugueseKeepsEuropeanPortugueseOnAnEuropeanIPhone() async throws {
        let text = "Estes são três hábitos que mudaram as minhas manhãs. Primeiro, bebo um copo de água antes de pegar no telemóvel."
        let european = FakeSpeechLocaleCatalog(transcriber: ["pt-PT", "pt-BR"], dictation: ["pt-PT", "pt-BR"])
        let route = try await route(.detect(text: text, systemLanguages: ["pt-PT", "en-GB"]), on: european).get()
        #expect(route.locale.identifier(.bcp47) == "pt-PT")
        // While a chosen Brazilian Portuguese never is.
        let chosen = try await self.route(.language(.portugueseBrazil), on: european).get()
        #expect(chosen.locale.identifier(.bcp47) == "pt-BR")
    }
}
