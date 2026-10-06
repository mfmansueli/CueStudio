//
//  FreeExportLabelsTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The words that count the free exports on 9.1, 8.1 and 6.3 (09, "Free exports running out").
@Suite("FreeExportLabels")
struct FreeExportLabelsTests {
    @Test(arguments: [(5, "5 OF 5 EXPORTS LEFT"), (4, "4 OF 5 EXPORTS LEFT"), (2, "2 OF 5 EXPORTS LEFT")])
    func theProfilePlanCardCountsDown(_ left: Int, _ text: String) {
        #expect(FreeExportLabels.plan(left: left) == FreeExportLabels.Label(text: text, tone: .quiet))
    }

    @Test func theLastOneIsYellowOnEverySurface() {
        #expect(FreeExportLabels.plan(left: 1) == FreeExportLabels.Label(text: "LAST FREE EXPORT", tone: .last))
        #expect(FreeExportLabels.meter(left: 1) == FreeExportLabels.Label(text: "LAST FREE EXPORT", tone: .last))
        #expect(FreeExportLabels.take(left: 1, declined: false) == FreeExportLabels.Label(text: "LAST FREE EXPORT", tone: .last))
    }

    @Test func noneLeftIsOrangeAndSaysWhatToDo() {
        #expect(FreeExportLabels.plan(left: 0) == FreeExportLabels.Label(text: "0 OF 5 EXPORTS LEFT", tone: .exhausted))
        #expect(FreeExportLabels.meter(left: 0) == FreeExportLabels.Label(text: "0 OF 5 LEFT · EXPORT WITH PRO", tone: .exhausted))
        #expect(FreeExportLabels.take(left: 0, declined: false) == FreeExportLabels.Label(text: "0 OF 5 FREE EXPORTS LEFT", tone: .exhausted))
    }

    @Test func afterNotNowTheTakeIsReadyToExportWithPro() {
        #expect(FreeExportLabels.take(left: 0, declined: true).text == "READY · EXPORT WITH PRO")
        #expect(FreeExportLabels.take(left: 3, declined: true).text == "3 OF 5 FREE EXPORTS LEFT", "only the empty count changes")
    }

    @Test func theMeterAndTheTakeLineHaveTheirOwnWords() {
        #expect(FreeExportLabels.meter(left: 3).text == "3 OF 5 LEFT")
        #expect(FreeExportLabels.take(left: 3, declined: false).text == "3 OF 5 FREE EXPORTS LEFT")
    }

    @Test func proIsUnlimitedEverywhere() {
        #expect(FreeExportLabels.plan(left: nil).text == "PRO · UNLIMITED")
        #expect(FreeExportLabels.meter(left: nil).text == "PRO · UNLIMITED EXPORTS")
        #expect(FreeExportLabels.take(left: nil, declined: true).text == "PRO · UNLIMITED EXPORTS")
        #expect(FreeExportLabels.take(left: nil, declined: false).tone == .quiet)
    }
}
