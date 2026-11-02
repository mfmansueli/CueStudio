import Testing
@testable import Cue_Studio

@Suite("Cloud draft factual review")
struct ScriptFactCheckPolicyTests {
    private var request: ScriptRequest {
        ScriptRequest(source: .prompt("An idea"), platform: .reels, voice: nil, targetRange: 30...60)
    }

    @Test func aCloudDraftStillNeedsReviewWhenTheModelClaimsItContainsNoFacts() {
        #expect(ScriptFactCheckPolicy.needsReview(for: request, on: .privateCloud, statesFacts: false))
    }

    @Test func localFactualSignalsStillCountWithoutChangingTheLocalNonfactualCase() {
        #expect(ScriptFactCheckPolicy.needsReview(for: request, on: .onDevice, statesFacts: true))
        #expect(!ScriptFactCheckPolicy.needsReview(for: request, on: .onDevice, statesFacts: false))
    }
}
