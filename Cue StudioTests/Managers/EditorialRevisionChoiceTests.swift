import Testing
@testable import Cue_Studio

@Suite("Editorial revision regression guards")
struct EditorialRevisionChoiceTests {
    private static let body = "Check the camera preview before recording. Compare the shadows on your face and adjust the curtain if direct sun is too harsh."

    private static func assess(_ text: String, violations: [VoiceViolation] = [], brief: IdeaBrief? = nil) -> DraftAssessment {
        let request = ScriptRequest(
            source: .prompt("Check the camera preview and shadows"), platform: .reels, voice: nil,
            targetRange: 60...90, language: .english, brief: brief
        )
        return DraftAssessment(text: text, violations: violations, request: request)
    }

    @Test func equalConstraintSeverityAllowsAnEditorialChange() {
        let changed = Self.body + " Compare both positions before choosing."
        #expect(EditorialRevisionChoice.accepts(original: Self.assess(Self.body), revision: Self.assess(changed)))
    }

    @Test func addingAForbiddenExpressionRejectsTheRevision() {
        let violation = VoiceViolation(kind: .avoided, detail: "Forbidden expression")
        #expect(!EditorialRevisionChoice.accepts(
            original: Self.assess(Self.body), revision: Self.assess(Self.body, violations: [violation])
        ))
    }

    @Test func droppingTheSelectedInspirationOpeningRejectsTheRevision() {
        let brief = IdeaBrief(subject: "Window light", angle: "", openingLine: "Look at the shadow first.")
        #expect(!EditorialRevisionChoice.accepts(
            original: Self.assess("Look at the shadow first. " + Self.body, brief: brief),
            revision: Self.assess(Self.body, brief: brief)
        ))
    }

    @Test func anUnfinishedOrGuttedRevisionCannotReplaceTheDraft() {
        #expect(!EditorialRevisionChoice.accepts(original: Self.assess(Self.body), revision: Self.assess(Self.body + " Then look at")))
        #expect(!EditorialRevisionChoice.accepts(original: Self.assess(Self.body), revision: Self.assess("Check the preview.")))
    }
}
