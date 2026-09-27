//
//  ScriptPanelClearanceTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("ScriptPanelClearance")
struct ScriptPanelClearanceTests {
    @Test func sheetStopsJustUnderThePanel() {
        // iPhone 17: the panel ends 400 pt down and the safe area 840 pt down.
        #expect(ScriptPanelClearance.sheetHeight(panelBottom: 400, safeAreaBottom: 840) == 428)
    }

    @Test func sheetTopLeavesTheGapUnderThePanel() {
        let safeAreaBottom: CGFloat = 840
        let height = ScriptPanelClearance.sheetHeight(panelBottom: 400, safeAreaBottom: safeAreaBottom)
        #expect(safeAreaBottom - height == 400 + ScriptPanelClearance.gap)
    }

    @Test func shortScreensKeepAUsableSheet() {
        // iPhone SE: little room below the panel.
        #expect(ScriptPanelClearance.sheetHeight(panelBottom: 358, safeAreaBottom: 520) == ScriptPanelClearance.minimumSheetHeight)
    }
}
