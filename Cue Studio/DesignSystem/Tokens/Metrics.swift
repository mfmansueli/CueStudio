//
//  Metrics.swift
//  Cue Studio
//

import CoreGraphics

/// Spacing, radii and control sizes.
enum Metrics {
    /// Side margin for cards and lists.
    static let gutter: CGFloat = 16
    /// Side margin for titles and loose text.
    static let textGutter: CGFloat = 20
    static let cardRadius: CGFloat = 26
    static let innerRadius: CGFloat = 20
    static let tileRadius: CGFloat = 18
    static let fieldRadius: CGFloat = 12
    /// Top corners of custom sheets.
    static let sheetRadius: CGFloat = 38
    static let buttonHeight: CGFloat = 50
    static let largeButtonHeight: CGFloat = 54
    static let compactButtonHeight: CGFloat = 34
    /// Tool buttons under a timeline (Remove part, Cut, Delete).
    static let mediumButtonHeight: CGFloat = 42
    /// Minimum touch target.
    static let hitTarget: CGFloat = 44
    static let chipHeight: CGFloat = 34

    // MARK: Editor (v10)

    /// Top corners of the panels under the timeline.
    static let editorPanelRadius: CGFloat = 22
    /// Room kept under a panel's last control, on top of the bottom safe area (the Home Indicator's
    /// strip): the panel's background runs to the screen's edge, its controls stop above both.
    static let editorPanelBottomClearance: CGFloat = 8
    /// Top corners of the editor's sheets.
    static let editorSheetRadius: CGFloat = 28
    /// Clips on the video track.
    static let clipRadius: CGFloat = 7
    /// Items on the other tracks.
    static let laneItemRadius: CGFloat = 6
    /// The editor's preview frame.
    static let editorPreviewRadius: CGFloat = 6
    /// The ✓ that applies and closes a panel.
    static let applyButtonSize: CGFloat = 40
}
