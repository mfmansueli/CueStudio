//
//  LanguageModelDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
@testable import Cue_Studio

/// Apple Intelligence on this device, language by language, through the service the app uses: which of
/// Cue's languages the model writes, whether what it writes comes back in the language asked for, whether a
/// translation lands in its target, and that the languages it doesn't write are refused before any request.
///
/// Opt-in and on a device with Apple Intelligence on (`TEST_RUNNER_CUE_AI_E2E=1`): it runs the real model.
/// Without it (the simulator, Apple Intelligence off, a model still downloading) the test is *not validated*
/// and says so, never passed.
@MainActor
@Suite(
    "Apple Intelligence on this device",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil)
)
struct LanguageModelDeviceTests {
    private static let ideas: [CueLanguage: String] = [
        .english: "Why I stopped drinking coffee for thirty days",
        .spanish: "Por qué dejé de tomar café durante treinta días",
        .portugueseBrazil: "Por que eu parei de tomar café por trinta dias",
        .french: "Pourquoi j'ai arrêté le café pendant trente jours",
        .german: "Warum ich dreißig Tage lang keinen Kaffee getrunken habe",
        .italian: "Perché ho smesso di bere caffè per trenta giorni",
        .japanese: "三十日間コーヒーをやめて分かったこと",
        .korean: "30일 동안 커피를 끊었더니 생긴 일",
        .chineseSimplified: "我三十天不喝咖啡后发生了什么",
        .turkish: "Otuz gün kahve içmeyi bıraktım ve sonuç şaşırtıcıydı",
        .vietnamese: "Vì sao tôi bỏ cà phê trong ba mươi ngày",
        .chineseTraditional: "我三十天不喝咖啡後發生了什麼",
        .dutch: "Waarom ik dertig dagen geen koffie dronk",
        .swedish: "Varför jag slutade dricka kaffe i trettio dagar",
        .danish: "Hvorfor jeg holdt op med at drikke kaffe i tredive dage",
        .norwegian: "Hvorfor jeg sluttet å drikke kaffe i tretti dager",
        .hindi: "मैंने तीस दिन कॉफ़ी क्यों छोड़ी",
        .indonesian: "Kenapa saya berhenti minum kopi selama tiga puluh hari",
        .arabic: "لماذا توقفت عن شرب القهوة لمدة ثلاثين يومًا",
        .thai: "ทำไมฉันเลิกกินกาแฟสามสิบวัน",
    ]

    private func service(_ language: CueLanguage) throws -> ScriptAIService {
        let service = ScriptAIService()
        guard service.availability.onDevice else {
            let reason = service.availability.reason ?? "unknown"
            print("AI \(language.rawValue): NOT VALIDATED · \(reason)")
            try Test.cancel("Apple Intelligence isn't available on this device: \(reason)")
        }
        return service
    }

    /// Which languages this device's model offers, and what the app's own check says for each.
    @Test func whatTheModelOffersForEachLanguage() async throws {
        _ = try service(.english)
        let model = SystemLanguageModel.default
        let supported = model.supportedLanguages.map(\.maximalIdentifier).sorted().joined(separator: " ")
        let checker = AppleLanguageCapabilityChecker()
        var lines: [String] = []
        for language in CueLanguage.allCases {
            let direct = model.supportsLocale(language.locale)
            let app = await checker.support(.aiWriting, for: language)
            lines.append("\(language.rawValue): model \(direct) · app \(app)")
            #expect((app == .supported) == direct, "\(language.rawValue): the app's answer disagrees with the model's")
        }
        print("AI SUPPORT (\(model.supportedLanguages.count) locales: \(supported)) · \(lines.joined(separator: " · "))")
    }

    @Test(arguments: CueLanguage.allCases)
    func aFreePromptComesBackInItsLanguageOrIsRefusedAtOnce(language: CueLanguage) async throws {
        let service = try service(language)
        let request = ScriptRequest(
            source: .prompt(try #require(Self.ideas[language])), platform: .tiktok, tone: nil, voice: nil,
            targetRange: 20...30, language: language
        )
        let supported = SystemLanguageModel.default.supportsLocale(language.locale)
        do {
            let script = try await service.generate(request)
            #expect(supported, "\(language.rawValue): written although the model doesn't list it")
            let right = OutputLanguageCheck.isPlausible(script.text, in: language)
            print("AI WRITE \(language.rawValue): \(script.text.split(whereSeparator: \.isWhitespace).count) words · in the language \(right) · “\(script.text.prefix(90))”")
            #expect(right, "\(language.rawValue): came back in another language: \(script.text.prefix(120))")
        } catch let error as ScriptAIError {
            guard case .unsupportedLanguage = error else {
                print("AI WRITE \(language.rawValue): \(error)")
                if case .modelPreparing = error { try Test.cancel("\(language.rawValue) not validated: the model is still preparing") }
                Issue.record("\(language.rawValue): \(error)")
                return
            }
            print("AI WRITE \(language.rawValue): refused before any request (language not written by the model)")
            #expect(!supported)
        }
    }

    @Test(arguments: [CueLanguage.english, .portugueseBrazil, .german, .japanese, .chineseTraditional])
    func aRewriteKeepsTheScriptsLanguage(language: CueLanguage) async throws {
        let service = try service(language)
        let script = try #require(VoiceFollowingSpeechTests.scripts[language])
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: 20...40, sourceLanguage: language.locale.language, voice: nil
        )
        let rewritten = try await service.rewrite(script, with: .moreEnergy, context: context)
        let right = OutputLanguageCheck.isPlausible(rewritten, in: language)
        print("AI REWRITE \(language.rawValue): in the language \(right) · “\(rewritten.prefix(90))”")
        #expect(right)
        let hooks = try await service.hooks(for: script, context: context)
        #expect(hooks.count == 3 && OutputLanguageCheck.isPlausible(hooks.joined(separator: " "), in: language))
    }

    @Test(arguments: [
        (CueLanguage.portugueseBrazil, CueLanguage.english), (.english, .german), (.japanese, .chineseTraditional), (.french, .spanish),
    ])
    func aTranslationLandsInItsTarget(source: CueLanguage, target: CueLanguage) async throws {
        let service = try service(source)
        let script = try #require(VoiceFollowingSpeechTests.scripts[source])
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: 20...40, language: target,
            sourceLanguage: source.locale.language, voice: nil
        )
        let translated = try await service.rewrite(script, with: .translate, context: context)
        let right = OutputLanguageCheck.isPlausible(translated, in: target)
        print("AI TRANSLATE \(source.rawValue)→\(target.rawValue): in the target \(right) · “\(translated.prefix(90))”")
        #expect(right)
        #expect(translated != script)
    }

    @Test func aTranslationNeedsBothLanguagesTheModelWrites() async throws {
        let service = try service(.english)
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: 20...40, language: .thai,
            sourceLanguage: CueLanguage.english.locale.language, voice: nil
        )
        do {
            _ = try await service.rewrite("Here are three habits that changed my mornings.", with: .translate, context: context)
            Issue.record("Thai is not a language the model writes")
        } catch let error as ScriptAIError {
            guard case .unsupportedTranslation = error else {
                Issue.record("Expected the pair to be named, got \(error)")
                return
            }
        }
    }

    // MARK: - My Cue Voice

    /// The creator's voice, as the card's "Write in my voice" sends it: a catchphrase, how they sound, their style.
    private static let voice = CreatorVoice(
        sounds: [.casual, .confident], phrases: ["Hey fam"], vocabulary: .simple, styles: [.storytelling], niches: [.lifestyle]
    )

    /// What the card on the main screen does when "Write in my voice" is on: the request carries the voice, the
    /// language is the script's (or the one read from the idea), and what comes back stays in that language.
    /// Through `ScriptRequestFactory`, the same path the arrow takes.
    @Test(arguments: [CueLanguage.english, .portugueseBrazil, .spanish, .german, .japanese, .dutch])
    func aScriptInMyVoiceComesBackInTheCreatorsLanguage(language: CueLanguage) async throws {
        let service = try service(language)
        let defaults = UserDefaults(suiteName: "ai-voice-\(UUID())") ?? .standard
        let profile = CreatorProfileService(defaults: defaults)
        profile.addPhrase("Hey fam")
        profile.saveVoiceSetup(niches: [.lifestyle], vocabulary: .simple, sounds: [.casual, .confident])
        let factory = ScriptRequestFactory(
            rules: PlatformRulesService(), profile: profile, scriptLanguage: nil, interfaceLanguage: .english,
            preferredLanguages: ["en-US"]
        )
        let idea = try #require(Self.ideas[language])
        let request = factory.request(idea: idea, platform: .tiktok, format: nil)
        #expect(request.voice != nil, "The voice is part of the request")
        #expect(request.language == language, "\(language.rawValue): read as \(String(describing: request.language))")
        let script = try await service.generate(request)
        let right = OutputLanguageCheck.isPlausible(script.text, in: language)
        print("AI VOICE \(language.rawValue): in the language \(right) · “\(script.text.prefix(100))”")
        #expect(right)
        // "In my voice" on an existing script keeps its language too.
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: 20...40, sourceLanguage: language.locale.language, voice: Self.voice
        )
        let rewritten = try await service.rewrite(script.text, with: .inMyVoice, context: context)
        #expect(OutputLanguageCheck.isPlausible(rewritten, in: language))
        print("AI IN MY VOICE \(language.rawValue): “\(rewritten.prefix(100))”")
    }

    /// A voice in a language the model doesn't write: refused with the language reason, never a script in another.
    @Test(arguments: [CueLanguage.thai, .hindi, .arabic, .indonesian])
    func aVoiceDoesNotMakeAnUnsupportedLanguageWork(language: CueLanguage) async throws {
        let service = try service(language)
        var request = ScriptRequest(
            source: .prompt(try #require(Self.ideas[language])), platform: .tiktok, tone: nil, voice: Self.voice,
            targetRange: 20...30, language: language
        )
        request.voice = Self.voice
        do {
            _ = try await service.generate(request)
            Issue.record("\(language.rawValue) was written")
        } catch let error as ScriptAIError {
            guard case .unsupportedLanguage = error else { Issue.record("\(language.rawValue): \(error)"); return }
        }
    }
}
