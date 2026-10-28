import Testing
@testable import Cue_Studio

@Suite("Editorial plan")
struct PCCScriptPlanTests {
    @Test func aBriefNoticeDoesNotAskTheWriterToInventDevelopment() {
        let plan = PCCScriptPlan(
            angle: "Correct the time", requirements: ["Keep 14:35", "Use we"],
            beats: ["We published the wrong time; correct it."], example: "", briefOnly: true
        )
        #expect(plan.writingDirection.contains("preserve the supplied information and stop"))
        #expect(plan.writingDirection.contains("Keep 14:35"))
        #expect(!plan.writingDirection.contains("Follow through on the argument"))
    }

    @Test func developmentRetainsRequirementsAndDistinctBeatsForTheWriter() {
        let plan = PCCScriptPlan(
            angle: "A script supports delivery", requirements: ["One advantage and limit for each"],
            beats: ["Bullet cues preserve freedom but require improvising.", "Full text preserves wording but risks sounding read."],
            example: "A rehearsal rather than a cage.", briefOnly: false
        )
        let direction = plan.writingDirection
        #expect(direction.contains("1. Bullet cues preserve freedom"))
        #expect(direction.contains("2. Full text preserves wording"))
        #expect(direction.contains("One advantage and limit for each"))
        #expect(direction.contains("not an outline"))
    }
}
