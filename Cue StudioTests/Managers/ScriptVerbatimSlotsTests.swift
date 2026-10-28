import Testing
@testable import Cue_Studio

@Suite("Exact wording placement")
struct ScriptVerbatimSlotsTests {
    @Test func onlyEmittedSlotsAreReplacedInContextWithoutInventingMissingWording() {
        let slots = ScriptVerbatimSlots(phrases: ["Menos prisa, más intención.", "14:35"])
        #expect(slots.restoring(in: "Planifica. CUE_EXACT_TEXT_0_END") == "Planifica. Menos prisa, más intención.")
        #expect(slots.restoring(in: "No wording supplied.") == "No wording supplied.")
        #expect(slots.restoring(in: "CUE_EXACT_TEXT_1_END") == "14:35")
        #expect(slots.hasUnresolvedMarker(in: "CUE_EXACT_TEXT_0"))
        #expect(!slots.hasUnresolvedMarker(in: slots.restoring(in: "CUE_EXACT_TEXT_1_END")))
        #expect(!slots.restoring(in: "CUE_EXACT_TEXT_1_END").contains("intención"))
    }

    @Test func creatorSuppliedMarkerSyntaxIsNeverInterpretedAsAnotherPhrase() {
        let slots = ScriptVerbatimSlots(phrases: ["CUE_EXACT_TEXT_1_END", "other"])
        #expect(slots.instruction.isEmpty)
        #expect(slots.restoring(in: "CUE_EXACT_TEXT_1_END") == "CUE_EXACT_TEXT_1_END")
    }
}
