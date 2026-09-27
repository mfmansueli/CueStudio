//
//  ScriptPanelClearance.swift
//  Cue Studio
//

import CoreGraphics

/// How tall a sheet over the Selfie prompter can grow while the script panel above it stays in sight.
nonisolated enum ScriptPanelClearance {
    /// Space kept between the bottom of the panel and the top of the sheet.
    static let gap: CGFloat = 12
    /// Any shorter and the sheet is too cramped to use, so on small screens it may cover the
    /// bottom of the panel.
    static let minimumSheetHeight: CGFloat = 240

    /// Height for a `.height` detent whose sheet stops just under the panel. Both edges are measured
    /// from the top of the screen; detent heights leave out the bottom safe area, so the sheet is
    /// measured up from where the safe area ends.
    static func sheetHeight(panelBottom: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        max(minimumSheetHeight, safeAreaBottom - panelBottom - gap)
    }
}
