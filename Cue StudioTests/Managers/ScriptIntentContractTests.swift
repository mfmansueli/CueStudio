//
//  ScriptIntentContractTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Intent benchmark input contracts")
struct ScriptIntentContractTests {
    @Test func theFrozenCasesFitTheActualDockAndDoNotLoseRequirementsInEitherRoute() throws {
        let cases = try ScriptIntentCase.load()
        #expect(cases.count == 33)
        #expect(Set(cases.map(\.id)).count == cases.count)
        #expect(Set(cases.map(\.language)) == [.portugueseBrazil, .english, .spanish])
        for item in cases {
            #expect(item.prompt.count <= IdeaPromptDraft.maxCharacters, "\(item.id): must fit the real card")
            #expect(["auto", "story", "talkingHead", "pov"].contains(item.format))
            let defaults = TestDefaults()
            defer { defaults.tearDown() }
            let profile = CreatorProfileService(defaults: defaults.defaults)
            profile.profile = try #require(QualityProfiles.all.first { $0.language == item.language }).full
            let factory = ScriptRequestFactory(
                rules: TestData.rulesService(), profile: profile, scriptLanguage: item.language, interfaceLanguage: item.language
            )
            let request = factory.request(idea: item.prompt, platform: .reels, format: nil, formatChoice: item.formatChoice)
            for route in [AIModelRoute.onDevice, .privateCloud] {
                let prepared = AIRequestPolicy.prepare(request, on: route)
                let prompt = ScriptPromptBuilder.prompt(for: prepared)
                #expect(prompt.contains(item.prompt), "\(item.id): the creator's complete request reaches \(route)")
                #expect(prepared.language == item.language)
                #expect(prepared.formatChoice == item.formatChoice)
                for literal in item.requiredLiterals { #expect(prompt.contains(literal)) }
                if route == .privateCloud {
                    #expect(PCCScriptDirection.usesAutomaticFormat(prepared) == (item.format == "auto"))
                    // The proof goes the way the device gets it (the owner's D1).
                    #expect(prepared.voice?.examples == request.voice?.examples && prepared.voice?.excerpts == request.voice?.excerpts)
                    #expect(prepared.voice?.approvedSamples == request.voice?.approvedSamples)
                }
            }
        }
    }
}
