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
    /// The corners of an inset-grouped section (Settings, Takes list). The system clips each row to its own corner (about 24 pt on iOS 27),
    /// so a `CardRowSlice` draws its shape at least that round: at 22 pt its edge fell outside the clip and vanished around every corner.
    static let groupedListRadius: CGFloat = 26
    /// The blocks of the v29 Profile (identity, universe, voice, plan).
    static let profileBlockRadius: CGFloat = 22
    /// The idea card on Scripts (the board's `.hero`).
    static let heroRadius: CGFloat = 22
    /// The Scripts dock (v30).
    static let dockRadius: CGFloat = 28
    static let innerRadius: CGFloat = 20
    static let tileRadius: CGFloat = 18
    static let fieldRadius: CGFloat = 12
    /// Top corners of custom sheets.
    static let sheetRadius: CGFloat = 38
    /// The navigation bar of a sheet (the native close button): added to a fitted sheet's height.
    static let sheetBarHeight: CGFloat = 56
    static let buttonHeight: CGFloat = 50
    static let largeButtonHeight: CGFloat = 54
    static let compactButtonHeight: CGFloat = 34
    /// Tool buttons under a timeline (Remove part, Cut, Delete).
    static let mediumButtonHeight: CGFloat = 42
    /// Minimum touch target.
    static let hitTarget: CGFloat = 44
    static let chipHeight: CGFloat = 34
    /// The filter chips of Takes (6.2): 32 pt on screen, 44 pt to touch.
    static let filterChipHeight: CGFloat = 32
    /// What a row of a grouped list puts inside the list's own padding: with it a row is 52 pt, and never under the 44 pt a touch needs.
    static let listRowContent: CGFloat = 32

    // MARK: Editor (v10)

    /// Top corners of the panels under the timeline.
    static let editorPanelRadius: CGFloat = 22
    /// Room kept under a panel's last control, on top of the bottom safe area (the Home Indicator's
    /// strip): the panel's background runs to the screen's edge, its controls stop above both.
    static let editorPanelBottomClearance: CGFloat = 8
    /// The same under the styling panels (Text style, Caption style), whose controls scroll: their last
    /// row (swatches, the captions action) kept clear of the Home Indicator, with the fade above it.
    static let editorStylePanelBottomClearance: CGFloat = 18
    /// The styling panels' grabber, a hint that the panel expands (the expand button does it too).
    static let editorPanelGrabber = CGSize(width: 36, height: 5)
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

    /// The system tab bar draws the icons from images: 26 pt, Record's 30 pt (`CueTabImage`).
    static let tabIconSize: CGFloat = 26
    static let tabRecordSize: CGFloat = 30

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
