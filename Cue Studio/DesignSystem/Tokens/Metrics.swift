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

    // MARK: - v29

    /// The gap between stacked blocks: nothing touches the block before it.
    static let blockGap: CGFloat = 16
    /// The bottom strip with no controls (the Home Indicator's).
    static let homeIndicatorClearance: CGFloat = 34

    /// The tab bar: a 64 pt capsule 16 pt from the sides and 26 pt from the bottom edge, with the active
    /// tab in a 56 pt capsule inset 4 pt. Icons are 26 pt, Record's 30 pt, labels 10 pt.
    static let tabBarHeight: CGFloat = 64
    static let tabBarSideMargin: CGFloat = 16
    static let tabBarBottomMargin: CGFloat = 26
    static let tabCapsuleHeight: CGFloat = 56
    static let tabCapsuleInset: CGFloat = 4
    static let tabIconSize: CGFloat = 26
    static let tabRecordSize: CGFloat = 30
    static let tabLabelSize: CGFloat = 10

    /// A topic's marker: a 3 pt bar, 30 pt tall in a list row and 14 pt in chips and legends.
    static let themeRailWidth: CGFloat = 3
    static let themeRailRowHeight: CGFloat = 30
    static let themeRailChipHeight: CGFloat = 14
    static let themeRailRadius: CGFloat = 2
    /// A network's marker: a 7 pt dot (6 pt in dense lines).
    static let platformDotSize: CGFloat = 7
    static let platformDotSmallSize: CGFloat = 6

    /// The "● REC" pill: 26 pt to see, 44 pt to touch.
    static let recPillHeight: CGFloat = 26
    static let recPillPadding: CGFloat = 9
    static let recPillRadius: CGFloat = 13
    static let recPillDotSize: CGFloat = 6

    /// The slider: a 4 pt track and a 24 pt thumb.
    static let sliderTrackHeight: CGFloat = 4
    static let sliderThumbSize: CGFloat = 24

    /// The AI bar over a selection.
    static let selectionBarHeight: CGFloat = 40
    static let selectionBarRadius: CGFloat = 20
    /// The state strip of the script page.
    static let stripHeight: CGFloat = 44
    static let stripRadius: CGFloat = 16
    /// The state chip.
    static let stateChipHeight: CGFloat = 22

    /// The empty-state mark and the star that orbits it.
    static let emptyRingSize: CGFloat = 88
    static let emptyOrbiterSize: CGFloat = 5
    /// "Your stars" in the sky.
    static let skyStarYouSize: CGFloat = 3
}
