//
//  InventedResultCaseTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The case of "Eu perdi 2 quilos em 7 dias" (iPhone 15 Pro, on this iPhone, 01/11/2026: `reports/entradas-do-criador-2026-11-01-medicao`,
/// pt-fitness-woman, idea 1), kept as what the code does with it (§11, A11a): the rule against invented results was in what the model read, and
/// nothing after it would have caught the number. Only the model's own `statesFacts` could ask for a fact check on this iPhone, and the run
/// didn't record it.
@MainActor
struct InventedResultCaseTests {
    private static let idea = "O dia em que eu desisti da dieta e o que aprendi com isso"

    private var request: ScriptRequest {
        let item = CreatorInputsDeviceTests.cases.first { $0.id == "pt-fitness-woman" }!
        return AIRequestPolicy.prepare(CreatorInputsDeviceTests.request(for: Self.idea, item: item), on: .onDevice)
    }

    @Test func theRuleAgainstInventedResultsWasInWhatTheModelRead() {
        let instructions = ScriptPromptBuilder.instructions(for: request)
        #expect(instructions.contains("Never invent personal stories, clients, results, numbers or credentials for the creator"))
    }

    @Test func onThisIPhoneOnlyTheModelsOwnFlagAsksForAFactCheck() {
        #expect(!request.isFactualTopic, "a personal story is not a factual topic (`FactualTopic`)")
        #expect(!ScriptFactCheckPolicy.needsReview(for: request, on: .onDevice, statesFacts: false), "the page says nothing")
        #expect(ScriptFactCheckPolicy.needsReview(for: request, on: .onDevice, statesFacts: true))
        #expect(ScriptFactCheckPolicy.needsReview(for: request, on: .privateCloud, statesFacts: false), "Private Cloud Compute always asks")
    }
}
