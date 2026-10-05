//
//  AIFailureReportTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
@testable import Cue_Studio

/// An Apple Intelligence failure is written down by its exact reason (most of them are one "Couldn't write it" to the creator) and the
/// iPhone's conditions, and never with the creator's words.
@MainActor
@Suite("AI failure report")
struct AIFailureReportTests {
    @Test func eachFrameworkErrorIsToldByItsOwnCase() {
        #expect(AIFailureReport.reason(of: LanguageModelError.guardrailViolation(.init(debugDescription: "unsafe"))) == ("guardrailViolation", "unsafe"))
        #expect(AIFailureReport.reason(of: LanguageModelError.timeout(.init(debugDescription: "slow"))).reason == "timeout")
        let tooLong = LanguageModelError.contextSizeExceeded(.init(contextSize: 4_096, tokenCount: 4_200, debugDescription: ""))
        #expect(AIFailureReport.reason(of: tooLong).reason == "contextSizeExceeded(4200/4096)")
        #expect(AIFailureReport.reason(of: LanguageModelSession.Error.concurrentRequests).reason == "concurrentRequests")
    }

    @Test func cuesOwnReasonsAndCancellationsAreToldApart() {
        #expect(AIFailureReport.reason(of: CancellationError()).reason == "cancelled")
        #expect(AIFailureReport.reason(of: ScriptAIError.emptyResponse).reason == "cue.emptyResponse")
        #expect(AIFailureReport.reason(of: AIPlanFailure.turnedOff).reason == "plan.turnedOff")
        #expect(AIFailureReport.reason(of: URLError(.timedOut)).reason.contains("NSURLErrorDomain -1001"))
    }

    @Test func theLineAndTheKeysSayWhatFailedAndWhere() {
        let report = AIFailureReport(
            operation: "script", route: .onDevice, reason: "guardrailViolation", detail: "unsafe", language: "pt-BR", seconds: 4.2,
            isFinal: true,
            conditions: .init(
                device: "iPhone16,1", system: "27.0.0", model: "available", thermal: "serious", lowPower: true, freeMemoryMB: 640,
                appState: "active"
            )
        )
        #expect(report.line.contains("script failed on onDevice after 4.20s: guardrailViolation (told the creator)"))
        #expect(report.line.contains("thermal=serious lowPower=true freeMemory=640MB app=active device=iPhone16,1"))
        #expect(report.keys["reason"] == "guardrailViolation" && report.keys["device"] == "iPhone16,1" && report.keys["final"] == "true")
    }

    @Test func theConditionsAreReadFromThisDevice() {
        let conditions = AIFailureReport.Conditions.current(appState: "active")
        #expect(!conditions.device.isEmpty && !conditions.model.isEmpty && conditions.freeMemoryMB >= 0)
    }
}
