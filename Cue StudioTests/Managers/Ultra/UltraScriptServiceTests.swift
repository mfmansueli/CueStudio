//
//  UltraScriptServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI's two calls with a fake client: nothing goes out without permission or past the cap, a revoked permission or a Stop keeps the second
/// call from leaving, only the polished script comes back (a failed polish is a failure, never the draft), and every call is counted.
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

    @Test func theDraftThenItsPolishAndOnlyThePolishComesBack() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let run = try await scenario.service.run(request)
        #expect(scenario.client.requests.map(\.stage) == [.draft, .review])
        #expect(scenario.client.requests[1].prompt.contains("A developed draft with a reason and an example."))
        #expect(run.script.text == "The polished script.")
        #expect(run.script.title == "Polished title")
        #expect(run.script.engine == .ultra && run.script.needsFactCheck)
        #expect(run.draft == "A developed draft with a reason and an example.")
        #expect(run.changes == ["Tightened the opening."])
        #expect(scenario.budget.used == 2)
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
        #expect(scenario.budget.used == 2)
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
        #expect(scenario.client.requests[2].prompt.contains("the creator chose 60 to 90 seconds"))
    }
}
