//
//  FilterFanPlanTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The folding filter row of Scripts and Takes (`FilterFanPlan`): where each chip sits closed and open, the dots, the order the chips
/// move in, and when the row folds at all.
struct FilterFanPlanTests {
    private let widths: [CGFloat] = [60, 90, 80, 85, 100]

    @Test func openTheChipsSitInTheirOwnOrderSpacingApart() {
        let plan = FilterFanPlan(widths: widths, selected: 2, isOpen: true)
        #expect(plan.slots == [0, 68, 166, 254, 347])
        #expect(plan.openWidth == 447)
        #expect(widths.indices.allSatisfy { plan.placement(at: $0).isShown && plan.placement(at: $0).opacity == 1 })
        #expect(plan.placement(at: 2).x == 166, "The chosen chip keeps its place: the order never changes")
        #expect(plan.peekCount == 0, "No dots on an open row")
    }

    @Test func foldedOnlyTheChosenChipShowsAtTheStartAndTheOthersWaitBehindIt() {
        let plan = FilterFanPlan(widths: widths, selected: 3, isOpen: false)
        let chosen = plan.placement(at: 3)
        #expect(chosen.x == 0 && chosen.isShown && chosen.opacity == 1)
        for index in [0, 1, 2, 4] {
            let hidden = plan.placement(at: index)
            #expect(!hidden.isShown && hidden.opacity == 0, "Neither tappable nor read")
            #expect(hidden.scale == FilterFanPlan.hiddenScale)
            #expect(hidden.x + widths[index] / 2 == widths[3] / 2, "Centred behind the chosen chip, so it comes out of it")
            #expect(hidden.zIndex < chosen.zIndex)
        }
        #expect(plan.placement(at: 2).zIndex > plan.placement(at: 0).zIndex, "The nearest sits on top of the farthest")
    }

    @Test func theDotsStandForUpToFourHiddenOptionsJustAfterTheChosenChip() {
        let plan = FilterFanPlan(widths: widths + [70, 70], selected: 1, isOpen: false)
        #expect(plan.peekCount == 4)
        #expect(plan.peekIndices == [0, 2, 3, 4], "In order, the chosen one left out")
        #expect(plan.peekX == widths[1] + FilterFanPlan.peekGap)
        #expect(FilterFanPlan.peekWidth(count: 4) == 4 * FilterFanPlan.peekDot + 3 * FilterFanPlan.peekSpacing)
        #expect(FilterFanPlan.peekWidth(count: 0) == 0)
    }

    @Test func unfoldingTheNearestChipLeavesFirstAndFoldingTheFarthest() {
        let open = FilterFanPlan(widths: widths, selected: 1, isOpen: true)
        #expect(open.delay(at: 1) == 0)
        #expect(open.delay(at: 0) == open.delay(at: 2), "Both neighbours leave together")
        #expect(open.delay(at: 2) < open.delay(at: 3) && open.delay(at: 3) < open.delay(at: 4))
        #expect(open.releaseTimes.count == 4)
        #expect(open.releaseTimes == open.releaseTimes.sorted())
        #expect((open.releaseTimes.first ?? 0) > 0, "A chip comes free a moment after it starts")

        let fold = FilterFanPlan(widths: widths, selected: 1, isOpen: false)
        #expect(fold.delay(at: 4) == 0, "The farthest starts home first")
        #expect(fold.delay(at: 2) > fold.delay(at: 4))
        #expect(fold.foldLanding == 3 * FilterFanPlan.foldStagger + FilterFanPlan.foldTravel, "The last lands after the nearest's way home")
        #expect(fold.foldLanding < 0.5, "A pick is a gesture, not a wait")
    }

    @Test func theRowFoldsFromTwoOptionsAndNeverForAssistiveTechnology() {
        #expect(!FilterFanPlan.folds(optionCount: 1, assistiveTechnology: false))
        #expect(FilterFanPlan.folds(optionCount: 2, assistiveTechnology: false), "All and one more fold too, like every row")
        #expect(FilterFanPlan.folds(optionCount: 3, assistiveTechnology: false))
        #expect(!FilterFanPlan.folds(optionCount: 6, assistiveTechnology: true), "VoiceOver and Switch Control get the open row")
    }

    @Test func aLongNameIsCutOnlyPastTheRowLessItsGuttersAndDots() {
        let width = FilterFanPlan.maxChipWidth(rowWidth: 393, gutter: 16, leadingWidth: 0)
        #expect(width == 393 - 32 - FilterFanPlan.peekGap - FilterFanPlan.peekWidth(count: 4))
        #expect(FilterFanPlan.maxChipWidth(rowWidth: 393, gutter: 16, leadingWidth: 150) < width, "The universe chip takes its room")
        #expect(FilterFanPlan.maxChipWidth(rowWidth: 120, gutter: 16, leadingWidth: 100) == 80, "Never under 80 pt")
        #expect(FilterFanPlan.maxChipWidth(rowWidth: 393, gutter: 16, leadingWidth: 0, hasPeek: false) > width, "A row that never folds keeps no room for dots")
    }

    @Test func theKeyChangesWithTheStateAndTheChosenChip() {
        let plan = FilterFanPlan(widths: widths, selected: 0, isOpen: false)
        var picked = plan
        picked.selected = 2
        var opened = plan
        opened.isOpen = true
        #expect(plan.key != picked.key && plan.key != opened.key)
        var measured = plan
        measured.widths = [61, 91, 81, 86, 101]
        #expect(plan.key == measured.key, "A chip measured again doesn't animate")
    }
}
