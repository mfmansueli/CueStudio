//
//  TypedFormatTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A format the creator typed under "What do you film most?" ("ASMR") is one of their formats: it is told in the formats line, which a long
/// brief never cuts, instead of among the tags, the third thing cut (`reports/entradas-do-criador-2026-11-01-completo.md` §11, A13).
@MainActor
struct TypedFormatTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = CreatorProfile(role: .personal, sounds: [.casual], confirmedVoiceSteps: [.tone])
        return (service, defaults)
    }

    @Test func aTypedFormatIsToldWithTheFormats() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        _ = service.answer(.formats, with: VoiceOption(id: ScriptType.tutorial.rawValue, label: ScriptType.tutorial.label))
        #expect(service.addSomethingElse("ASMR", for: .formats) == .added)
        #expect(service.profile.customFormats == ["ASMR"] && service.profile.customTags.isEmpty)
        #expect(service.profile.isAnswered(.formats))
        let text = VoiceBriefBuilder.brief(for: service.profile.voice).text
        #expect(text.contains("They film mostly: tutorials, ASMR."), "\(text)")
        #expect(!text.contains("Also true of them"))
    }

    @Test func theFormatsLineSurvivesABriefCutToItsBudget() {
        var profile = CreatorProfile(role: .personal, sounds: [.casual], confirmedVoiceSteps: [.tone])
        profile.customFormats = ["ASMR"]
        profile.customTags = ["Night owl"]
        profile.reach.platforms = [.tiktok]
        let full = VoiceBriefBuilder.brief(for: profile.voice).text
        // Room for everything but where they post and the tags: the two are cut, in that order (`VoiceBriefBuilder`).
        let kept = full.split(separator: "\n").filter { !$0.hasPrefix("They post on") && !$0.hasPrefix("Also true of them") }
        let tight = VoiceBriefBuilder.brief(for: profile.voice, budget: PromptCost.units(of: kept.joined(separator: "\n")))
        #expect(tight.trimmed.contains(.tags), "the budget is small enough to cut the tags: \(tight.trimmed)")
        #expect(tight.text.contains("ASMR") && !tight.text.contains("Night owl"), "\(tight.text)")
    }

    @Test func theLimitCountsTypedFormatsAndTappingOneRemovesIt() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        for name in ["ASMR", "Unboxing", "Street interviews"] { _ = service.addSomethingElse(name, for: .formats) }
        let fourth = service.addSomethingElse("Duets", for: .formats)
        #expect(VoiceLimits.formats == 3)
        if case .limit = fourth {} else { Issue.record("a fourth format goes past the limit: \(fourth)") }
        service.removeTypedFormat("asmr")
        #expect(service.profile.customFormats == ["Unboxing", "Street interviews"])
    }

    @Test func aFormatAnOlderBuildKeptAsATagCanBeRemovedToo() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.profile.customTags = ["Reaction videos"]
        service.removeTypedFormat("Reaction videos")
        #expect(service.profile.customTags.isEmpty)
    }

    @Test func typedFormatsAreSavedAndLeaveWithTheCatalogOnlyRetry() throws {
        var profile = CreatorProfile()
        profile.customFormats = ["ASMR"]
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.customFormats == ["ASMR"])
        #expect(decoded.voice.catalogOnly.customFormats.isEmpty, "the retry after a refusal sends nothing the creator typed")
    }
}
