//
//  ScriptAIServiceLanguageTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
@testable import Cue_Studio

/// What `ScriptAIService` decides before it sends anything: whether the languages of a request are
/// ones Apple Intelligence writes. These never reach the model, so they run anywhere; what the model
/// writes is checked on a device (`LanguageModelDeviceTests`).
@Suite("ScriptAIService languages")
@MainActor
struct ScriptAIServiceLanguageTests {
    private func makeService(_ capabilities: FakeAIModelCapabilities = FakeAIModelCapabilities()) -> ScriptAIService {
        ScriptAIService(usesPrivateCloudCompute: false, capabilities: capabilities)
    }

    private func context(language: CueLanguage? = nil, source: String? = nil) -> RewriteContext {
        RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: 30...45, language: language,
            sourceLanguage: source.map(Locale.Language.init(identifier:)), voice: nil
        )
    }

    private func request(_ idea: String = "Why I quit coffee", language: CueLanguage?, format: ScriptType? = nil) -> ScriptRequest {
        ScriptRequest(
            source: .prompt(idea), platform: .tiktok, tone: nil, voice: nil, targetRange: 30...45, language: language, format: format
        )
    }

    // MARK: - Writing

    @Test func aFreePromptInALanguageTheModelDoesntWriteFailsAtOnceWithTheLanguageError() async {
        let service = makeService()
        for language in [CueLanguage.hindi, .indonesian, .arabic, .thai] {
            await #expect(throws: ScriptAIError.self) {
                _ = try await service.generate(request(language: language))
            }
            do {
                _ = try await service.generate(request(language: language))
            } catch let error as ScriptAIError {
                guard case .unsupportedLanguage = error else {
                    Issue.record("\(language.rawValue): expected the language error, got \(error)")
                    continue
                }
                #expect(error.explainsItself)
            } catch {
                Issue.record("Unexpected error \(error)")
            }
        }
    }

    /// A format has its own draft, in the language, that needs no model: still available when the model can't write it.
    @Test func aFormatInAnUnsupportedLanguageFallsBackToItsStructuredDraft() async throws {
        let service = makeService()
        let brief: [String: String] = [:]
        let request = ScriptRequest(
            source: .format(.review, brief: brief), platform: .tiktok, tone: .casual, voice: nil, targetRange: 30...45, language: .thai
        )
        let draft = try await service.generate(request)
        #expect(draft.usedLanguageModel == false)
        #expect(!draft.text.isEmpty)
    }

    @Test func appleIntelligenceThatIsOffIsToldAsSuch() async {
        let service = makeService(FakeAIModelCapabilities(device: .turnedOff))
        do {
            _ = try await service.generate(request(language: .english))
            Issue.record("A free prompt can't be written with Apple Intelligence off")
        } catch let error as ScriptAIError {
            guard case .modelUnavailable(let reason) = error else {
                Issue.record("Expected the reason it's off, got \(error)")
                return
            }
            #expect(reason == AIModelStatus.turnedOff.reason)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func aModelStillPreparingIsNotCalledALanguageProblem() async {
        let service = makeService(FakeAIModelCapabilities(device: .preparing))
        do {
            _ = try await service.generate(request(language: .english))
        } catch let error as ScriptAIError {
            guard case .modelPreparing = error else {
                Issue.record("Expected a model that is still getting ready, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    // MARK: - Rewriting and translating

    @Test func aRewriteOfAScriptInAnUnsupportedLanguageIsToldBeforeAnythingIsSent() async {
        let service = makeService()
        do {
            _ = try await service.rewrite("สวัสดีทุกคน", with: .moreEnergy, context: context(source: "th"))
            Issue.record("Thai can't be rewritten by a model that doesn't write it")
        } catch let error as ScriptAIError {
            guard case .unsupportedLanguage = error else {
                Issue.record("Expected the language error, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func aTranslationNamesThePairWhenEitherLanguageIsUnsupported() async {
        let service = makeService()
        // Portuguese is written; Thai isn't: the pair is named, not "this script's language".
        do {
            _ = try await service.rewrite("Olá a todos", with: .translate, context: context(language: .thai, source: "pt"))
            Issue.record("Translation into Thai needs a model that writes it")
        } catch let error as ScriptAIError {
            guard case .unsupportedTranslation(let source, let target) = error else {
                Issue.record("Expected the pair, got \(error)")
                return
            }
            #expect(source == CueLanguage.portugueseBrazil.localizedName)
            #expect(target == CueLanguage.thai.localizedName)
            #expect(error.errorDescription?.contains(target) == true)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        // The source counts too: nothing is translated from a language the model doesn't read.
        do {
            _ = try await service.rewrite("สวัสดี", with: .translate, context: context(language: .portugueseBrazil, source: "th"))
            Issue.record("Translation from Thai needs a model that reads it")
        } catch let error as ScriptAIError {
            guard case .unsupportedTranslation = error else {
                Issue.record("Expected the pair, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    /// There is no language to translate into by default: the creator's pick is the only one.
    @Test func aTranslationWithoutATargetNeverPicksOne() async {
        let service = makeService()
        await #expect(throws: ScriptAIError.self) {
            _ = try await service.rewrite("Olá a todos", with: .translate, context: context(language: nil, source: "pt"))
        }
    }

    @Test func hooksAndIdeasAreCheckedLikeEverythingElse() async {
        let service = makeService()
        await #expect(throws: ScriptAIError.self) {
            _ = try await service.hooks(for: "مرحبا بالجميع", context: context(source: "ar"))
        }
        await #expect(throws: ScriptAIError.self) {
            _ = try await service.themeIdeas(for: [.tech], language: .hindi)
        }
    }

    // MARK: - Asking before a flight

    @Test func theQuickCheckIsAnswerableWithoutAModel() {
        let service = makeService()
        #expect(service.writingFailure(in: [Locale.Language(identifier: "pt-BR")]) == nil)
        #expect(service.writingFailure(in: [Locale.Language(identifier: "th-TH")]) != nil)
        #expect(service.writingFailure(in: []) == nil)
    }

    @Test func availabilityFollowsTheDeviceModelNotTheLanguage() {
        #expect(makeService().availability.isAvailable)
        let off = makeService(FakeAIModelCapabilities(device: .turnedOff))
        #expect(off.availability.isAvailable == false)
        #expect(off.availability.reason == AIModelStatus.turnedOff.reason)
    }
}

// MARK: - Falling back and retrying

@Suite("ScriptAIService fallback")
@MainActor
struct ScriptAIServiceFallbackTests {
    private let ranOut = LanguageModelError.contextSizeExceeded(.init(contextSize: 4096, tokenCount: 4100, debugDescription: "ran out"))

    private func service(cloud: Bool = false) -> ScriptAIService {
        ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities())
    }

    private func plan(usable: Set<AIModelRoute> = [.onDevice]) -> AIPlan {
        AIPlan(route: .onDevice, usable: usable)
    }

    @Test func aShortRequestThatRanOutIsTriedOnceMore() async throws {
        var calls = 0
        let result = try await service().withFallback(plan(), retriesRunaway: true) { _ in
            calls += 1
            if calls == 1 { throw ranOut }
            return "ok"
        }
        #expect(result == "ok" && calls == 2)
    }

    @Test func aLongRequestIsNotRetriedAndSaysTooLong() async {
        var calls = 0
        do {
            _ = try await service().withFallback(plan(), retriesRunaway: false) { _ -> String in
                calls += 1
                throw ranOut
            }
            Issue.record("Should have failed")
        } catch let error as ScriptAIError {
            guard case .tooLong = error else { Issue.record("Expected too long, got \(error)"); return }
            #expect(calls == 1)
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test func aRequestThatKeepsRunningOutGivesUpAfterOneRetry() async {
        var calls = 0
        do {
            _ = try await service().withFallback(plan(), retriesRunaway: true) { _ -> String in
                calls += 1
                throw ranOut
            }
        } catch let error as ScriptAIError {
            guard case .tooLong = error else { Issue.record("Expected too long, got \(error)"); return }
            #expect(calls == 2)
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test func aCancellationIsPassedOnAsIsAndNeverRetried() async {
        var calls = 0
        do {
            _ = try await service().withFallback(plan(usable: [.onDevice, .privateCloud]), retriesRunaway: true) { _ -> String in
                calls += 1
                throw CancellationError()
            }
        } catch {
            #expect(error is CancellationError)
        }
        #expect(calls == 1)
    }

    /// A model the plan doesn't list is never tried, however the failure reads.
    @Test func aModelOutsideThePlanIsNeverTheFallback() async {
        var models: [AIModelRoute] = []
        do {
            _ = try await service().withFallback(plan(usable: [.onDevice])) { model -> String in
                models.append(model)
                throw LanguageModelError.unsupportedLanguageOrLocale(.init(languageCode: "th", debugDescription: "th"))
            }
        } catch let error as ScriptAIError {
            guard case .unsupportedLanguage = error else { Issue.record("Expected the language error, got \(error)"); return }
        } catch {
            Issue.record("Unexpected \(error)")
        }
        #expect(models == [.onDevice])
    }

    @Test func aPreparingModelIsToldAsSuch() async {
        do {
            _ = try await service().withFallback(plan()) { _ -> String in
                throw SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: "downloading"))
            }
        } catch let error as ScriptAIError {
            guard case .modelPreparing = error else { Issue.record("Expected preparing, got \(error)"); return }
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }
}
