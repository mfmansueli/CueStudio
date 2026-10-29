//
//  UltraScriptServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI's calls with a fake client: nothing goes out without permission or past the cap, a revoked permission or a Stop keeps the next call
/// from leaving, only the polished script comes back (a failed check or polish is a failure, never the draft), and every call is counted. With
/// the claim check (`UltraFlow.checked`) the polish works on the checked draft and keeps its corrections.
@MainActor
@Suite("Ultra AI script service")
struct UltraScriptServiceTests {
    private struct Scenario {
        let service: UltraScriptService
        let client: FakeUltraModelClient
        let consent: UltraConsentService
        let budget: UltraCallBudget
        let defaults: TestDefaults
    }

    private func makeScenario(allowed: Bool = true, limit: Int = 30, available: Bool = true) -> Scenario {
        let defaults = TestDefaults()
        let consent = UltraConsentService(defaults: defaults.defaults)
        if allowed { consent.grant() }
        let budget = UltraCallBudget(defaults: defaults.defaults, limit: limit)
        let client = FakeUltraModelClient()
        let service = UltraScriptService(isAvailable: available, consent: consent, budget: budget) { client.made() }
        return Scenario(service: service, client: client, consent: consent, budget: budget, defaults: defaults)
    }

    private var request: ScriptRequest {
        var request = ScriptRequest(source: .prompt("Why I stopped buying bottled water"), platform: .tiktok, tone: nil, voice: nil, targetRange: 60...90)
        request.engine = .ultra
        return request
    }

    @Test func withoutPermissionNothingIsMadeOrSent() async {
        let scenario = makeScenario(allowed: false)
        defer { scenario.defaults.tearDown() }
        await #expect(throws: UltraError.consentRequired) { try await scenario.service.generate(request, reporting: nil) }
        #expect(scenario.client.requests.isEmpty && scenario.client.madeCount == 0 && scenario.budget.used == 0)
    }

    @Test func whereUltraIsntOfferedNothingIsMade() async {
        let scenario = makeScenario(available: false)
        defer { scenario.defaults.tearDown() }
        await #expect(throws: UltraError.notAvailable) { try await scenario.service.generate(request, reporting: nil) }
        #expect(scenario.client.madeCount == 0 && scenario.client.requests.isEmpty)
    }

    /// The app's flow: the draft, its claims checked, then the polish (the comparison of 29/10/2026 chose the check).
    @Test func theDraftItsCheckThenItsPolishAndOnlyThePolishComesBack() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let run = try await scenario.service.run(request)
        #expect(run.flow == .checked)
        #expect(scenario.client.requests.map(\.stage) == [.draft, .check, .review])
        #expect(scenario.client.requests[1].prompt.contains("A developed draft with a reason and an example."))
        #expect(run.script.text == "The polished script.")
        #expect(run.script.title == "Polished title")
        #expect(run.script.engine == .ultra && run.script.needsFactCheck)
        #expect(run.draft == "A developed draft with a reason and an example.")
        #expect(run.changes == ["Tightened the opening."])
        #expect(scenario.budget.used == 3)
    }

    @Test func revokedWhileTheDraftIsOutThePolishNeverLeaves() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.whileCalling = { stage in if stage == .draft { scenario.consent.revoke() } }
        await #expect(throws: UltraError.consentRevoked) { try await scenario.service.generate(request, reporting: nil) }
        #expect(scenario.client.requests.map(\.stage) == [.draft])
    }

    @Test func stoppedWhileTheDraftIsOutThePolishNeverLeaves() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let request = request
        let task = Task { try await scenario.service.generate(request, reporting: nil) }
        scenario.client.whileCalling = { stage in if stage == .draft { task.cancel() } }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(scenario.client.requests.map(\.stage) == [.draft])
    }

    @Test func aFailedPolishIsAFailureWithTheDraftKeptApart() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.review = .failure(UltraClientError(failure: .provider))
        do {
            _ = try await scenario.service.generate(request, reporting: nil)
            Issue.record("A failed polish returned a script")
        } catch let UltraError.reviewFailed(failure, draft) {
            #expect(failure == .provider && draft == "A developed draft with a reason and an example.")
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(scenario.budget.used == 3)
    }

    @Test func aScriptIsCountedOnlyOnceWritten() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let consent = UltraConsentService(defaults: defaults.defaults)
        consent.grant()
        let client = FakeUltraModelClient()
        let allowance = UltraAllowanceService(defaults: defaults.defaults, membership: { .free })
        let service = UltraScriptService(client: client, consent: consent, budget: UltraCallBudget(defaults: defaults.defaults), allowance: allowance)
        _ = try await service.generate(request, reporting: nil)
        #expect(allowance.left == 4 && service.scriptsLeft == 4)
        client.review = .failure(UltraClientError(failure: .provider))
        _ = try? await service.generate(request, reporting: nil)
        #expect(allowance.left == 4)
    }

    @Test func withNoScriptsLeftNothingGoesOut() async {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let consent = UltraConsentService(defaults: defaults.defaults)
        consent.grant()
        let client = FakeUltraModelClient()
        let allowance = UltraAllowanceService(defaults: defaults.defaults, membership: { .free })
        allowance.setFreeLeft(0)
        let budget = UltraCallBudget(defaults: defaults.defaults)
        let service = UltraScriptService(client: client, consent: consent, budget: budget, allowance: allowance)
        await #expect(throws: UltraError.noScriptsLeft) { try await service.generate(request, reporting: nil) }
        #expect(client.requests.isEmpty && budget.used == 0)
    }

    @Test func aPolishThatIsntTheThreeKeysIsAFailure() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.review = .success(UltraModelReply(text: "Here is your script: The polished script.", finishedNormally: true))
        await #expect(throws: UltraError.reviewFailed(.incomplete, draft: "A developed draft with a reason and an example.")) {
            try await scenario.service.generate(request, reporting: nil)
        }
    }

    @Test func aDraftCutAtTheTokenCapIsNeverPolished() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.draft = .success(UltraModelReply(text: "A draft that stops mid", finishedNormally: false))
        await #expect(throws: UltraError.draftFailed(.incomplete)) { try await scenario.service.generate(request, reporting: nil) }
        #expect(scenario.client.requests.map(\.stage) == [.draft])
    }

    @Test func aFailedDraftIsCountedAndNothingFollows() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.draft = .failure(UltraClientError(failure: .unreachable))
        await #expect(throws: UltraError.draftFailed(.unreachable)) { try await scenario.service.generate(request, reporting: nil) }
        #expect(scenario.budget.used == 1 && scenario.client.requests.count == 1)
    }

    @Test func withoutRoomForBothCallsNoneGoesOut() async {
        let scenario = makeScenario(limit: 1)
        defer { scenario.defaults.tearDown() }
        await #expect(throws: UltraError.budgetExhausted) { try await scenario.service.generate(request, reporting: nil) }
        #expect(scenario.client.requests.isEmpty && scenario.budget.used == 0)
    }

    @Test func theRequestsLengthIsWhatTheDraftIsAsked() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        var automatic = request
        automatic.durationPolicy = .informative
        _ = try await scenario.service.run(automatic)
        #expect(scenario.client.requests[0].prompt.contains("Length: free."))
        _ = try await scenario.service.run(request, length: .required(60...90))
        #expect(scenario.client.requests.last { $0.stage == .draft }?.prompt.contains("the creator chose 60 to 90 seconds") == true)
    }

    // MARK: - The claim check

    @Test func theCheckedDraftIsWhatThePolishWorksOn() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let run = try await scenario.service.run(request, flow: .checked)
        #expect(scenario.client.requests.map(\.stage) == [.draft, .check, .review])
        #expect(scenario.client.requests[1].prompt.contains("Draft to check:\n\"\"\"\nA developed draft with a reason and an example."))
        let polish = scenario.client.requests[2].prompt
        #expect(polish.contains("Draft to polish:\n\"\"\"\nA checked draft with a reason and an example."))
        #expect(polish.contains("Corrected by the check:\n- A universal rule now says when it applies."))
        #expect(run.checked == "A checked draft with a reason and an example." && run.corrections.count == 1 && run.flow == .checked)
        #expect(run.script.text == "The polished script." && scenario.budget.used == 3)
    }

    @Test func withoutTheCheckThePolishIsToldNothingWasChecked() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        _ = try await scenario.service.run(request, flow: .polished)
        #expect(!scenario.client.requests[1].prompt.contains("already checked"))
    }

    @Test func aCheckWithNothingToCorrectStillHoldsThePolishToTheFacts() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.check = .success(UltraModelReply(text: #"{"script":"Same draft.","corrections":[]}"#, finishedNormally: true))
        _ = try await scenario.service.run(request, flow: .checked)
        let polish = scenario.client.requests[2].prompt
        #expect(polish.contains("add no new facts, numbers, studies or technical claims") && !polish.contains("Corrected by the check"))
    }

    @Test func aFailedCheckIsAFailureAndThePolishNeverLeaves() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.check = .success(UltraModelReply(text: #"{"script":"Checked.","corrections":[],"verdict":"ok"}"#, finishedNormally: true))
        do {
            _ = try await scenario.service.run(request, flow: .checked)
            Issue.record("A failed check returned a script")
        } catch let UltraError.reviewFailed(failure, draft) {
            #expect(failure == .incomplete && draft == "A developed draft with a reason and an example.")
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(scenario.client.requests.map(\.stage) == [.draft, .check] && scenario.budget.used == 2)
    }

    @Test func revokedWhileTheCheckIsOutThePolishNeverLeaves() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.whileCalling = { stage in if stage == .check { scenario.consent.revoke() } }
        await #expect(throws: UltraError.consentRevoked) { try await scenario.service.run(request, flow: .checked) }
        #expect(scenario.client.requests.map(\.stage) == [.draft, .check])
    }

    @Test func withoutRoomForAllThreeCallsNoneGoesOut() async {
        let scenario = makeScenario(limit: 2)
        defer { scenario.defaults.tearDown() }
        await #expect(throws: UltraError.budgetExhausted) { try await scenario.service.run(request, flow: .checked) }
        #expect(scenario.client.requests.isEmpty && scenario.budget.used == 0)
    }

    @Test func theCheckIsReadStrictly() {
        #expect(UltraCheckReply(json: #"{"script":" A draft. ","corrections":["One."," "]}"#)?.corrections == ["One."])
        #expect(UltraCheckReply(json: #"{"script":"A draft.","corrections":[]}"#)?.script == "A draft.")
        #expect(UltraCheckReply(json: #"{"script":"","corrections":[]}"#) == nil)
        #expect(UltraCheckReply(json: #"{"script":"A draft."}"#) == nil)
        #expect(UltraCheckReply(json: #"{"script":"A draft.","corrections":[1]}"#) == nil)
        #expect(UltraCheckReply(json: "A draft.") == nil)
    }

    // MARK: - Fit to time

    /// 300 words, twice TikTok's 60–90 seconds.
    private var longScript: String { Array(repeating: "Light from the side shapes the face and the eyes.", count: 30).joined(separator: " ") }

    private func fitRequest(_ script: String) -> UltraFitRequest {
        UltraFitRequest(script: script, platform: .tiktok, range: 60...90)
    }

    @Test func aLongScriptIsFittedInOneCallWithItsRange() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let fitted = try await scenario.service.fit(fitRequest(longScript))
        #expect(fitted == "The fitted script.")
        #expect(scenario.client.requests.map(\.stage) == [.fit] && scenario.budget.used == 1)
        let prompt = scenario.client.requests[0].prompt
        #expect(prompt.contains("between 150 and 225 words") && prompt.contains("The script has 300 words now."))
        #expect(prompt.contains("Script to fit:\n\"\"\"\nLight from the side"))
    }

    @Test func aScriptAlreadyInTheRangeCostsNoCall() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let script = Array(repeating: "Light from the side shapes the face.", count: 25).joined(separator: " ")
        #expect(try await scenario.service.fit(fitRequest(script)) == script)
        #expect(scenario.client.requests.isEmpty && scenario.budget.used == 0)
    }

    @Test func withoutPermissionNothingIsFitted() async {
        let scenario = makeScenario(allowed: false)
        defer { scenario.defaults.tearDown() }
        await #expect(throws: UltraError.consentRequired) { try await scenario.service.fit(fitRequest(longScript)) }
        #expect(scenario.client.requests.isEmpty)
    }

    @Test func aFitThatIsntTheScriptAloneIsAFailure() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.client.fit = .success(UltraModelReply(text: #"{"script":"Short.","note":"cut the middle"}"#, finishedNormally: true))
        await #expect(throws: UltraError.fitFailed(.incomplete)) { try await scenario.service.fit(fitRequest(longScript)) }
        scenario.client.fit = .failure(UltraClientError(failure: .unreachable))
        await #expect(throws: UltraError.fitFailed(.unreachable)) { try await scenario.service.fit(fitRequest(longScript)) }
        #expect(scenario.budget.used == 2)
    }

    @Test func theFitIsReadStrictly() {
        #expect(UltraFitReply(json: #"{"script":" Fitted. "}"#)?.script == "Fitted.")
        #expect(UltraFitReply(json: #"{"script":""}"#) == nil)
        #expect(UltraFitReply(json: #"{"script":"Fitted.","title":"x"}"#) == nil)
        #expect(UltraFitReply(json: "Fitted.") == nil)
    }
}
