//
//  EditorLayout.swift
//  Cue Studio
//

import CoreGraphics

/// The editor's vertical height budget, from the usable height under the navigation bar (Back · status · Done, the system's)
/// and above the bottom safe area: preview, player bar, timeline, and the toolbar or a panel. Nothing is placed at fixed
/// positions; every screen gets the same rules.
///
/// - Nothing open: the timeline takes 32% (184–300 pt) and the preview the rest.
/// - A panel open (it replaces the toolbar): the preview keeps its size and the timeline gives up
///   its room. A panel that works on the timeline (all but the full ones) keeps the ruler and the
///   video track (and the track it is about) visible, taking that room from the preview down to its
///   minimum (30% of the height, at least 190 pt): the video never goes. Past that the panel gets
///   shorter and scrolls inside.
/// - On a very compact screen (iPhone SE) the full panels open as a sheet whose top stops under the
///   smallest preview, never over the video.
/// - With the keyboard up (a field in a panel is being typed in) the height left is shorter, but what
///   the screen *is* doesn't change: the height class and how the panel is shown come from the
///   height without the keyboard (`stableHeight`), so opening the keyboard can't turn the panel into
///   a sheet or change the bars and tracks. Only the room is shared again: the video above gets
///   smaller, the timeline steps aside and the panel sits right over the keyboard, tall enough for
///   its header and its field.
nonisolated struct EditorLayout: Equatable, Sendable {
    /// How a panel is shown.
    enum PanelPresentation: Equatable, Sendable {
        /// Under the timeline, in place of the toolbar.
        case inline
        /// A sheet with two heights: `medium`, and `large`, whose top stays under the preview.
        case sheet(medium: CGFloat, large: CGFloat)
    }

    let usableHeight: CGFloat
    /// The height with no keyboard: what decides the class and the presentation.
    let stableHeight: CGFloat
    /// The keyboard takes part of the height.
    let keyboardIsUp: Bool
    let heightClass: EditorHeightClass
    let preview: CGFloat
    let playerBar: CGFloat
    let timeline: CGFloat
    /// Zero while a panel is open.
    let toolbar: CGFloat
    /// Zero with nothing open, or when the panel is a sheet.
    let panel: CGFloat
    let panelPresentation: PanelPresentation
    /// The panel is shorter than its size: its content scrolls.
    let panelIsCompressed: Bool

    /// Height the keyboard has to take before it counts (a hardware keyboard's bar doesn't).
    static let keyboardThreshold: CGFloat = 100

    static let toolbarHeight: CGFloat = 64
    /// Room left under the last track.
    static let timelineBottomPadding: CGFloat = 8
    static let laneGap: CGFloat = 6

    /// The smallest the preview gets, whatever is open.
    static func previewMinimum(for usable: CGFloat) -> CGFloat {
        max(0.30 * usable, 190)
    }

    /// The smallest the video gets while the keyboard is up: enough to see the text being typed. The
    /// panel's header and field need the rest.
    static func previewMinimumWithKeyboard(for usable: CGFloat) -> CGFloat {
        max(0.22 * usable, 130)
    }

    /// The timeline with nothing open.
    static func restingTimeline(for usable: CGFloat) -> CGFloat {
        EditorPanelSize.clamp(0.32 * usable, 184, 300)
    }

    /// - Parameters:
    ///   - usableHeight: under the navigation bar, above the bottom safe area, and above the keyboard when it is up.
    ///   - stableHeight: the same without the keyboard; nil when there is none.
    ///   - panel: the open panel's size, if any.
    ///   - panelFocusesLane: the open panel is about one track (texts, captions, voice-over), which
    ///     then shows under the ruler too.
    ///   - largeText: Dynamic Type is large enough to make a regular screen compact.
    init(
        usableHeight: CGFloat, stableHeight: CGFloat? = nil, panel: EditorPanelSize? = nil,
        panelFocusesLane: Bool = false, largeText: Bool = false
    ) {
        let usable = max(0, usableHeight)
        let stable = max(usable, stableHeight ?? usable)
        let keyboardIsUp = stable - usable >= Self.keyboardThreshold
        // The class and the presentation come from the screen, not from what the keyboard left.
        let heightClass = EditorHeightClass(usableHeight: stable, largeText: largeText)
        self.usableHeight = usable
        self.stableHeight = stable
        self.keyboardIsUp = keyboardIsUp
        self.heightClass = heightClass
        playerBar = heightClass.playerBarHeight
        let bars = playerBar
        let restingTimeline = Self.restingTimeline(for: usable)
        let restingPreview = max(0, usable - bars - restingTimeline - Self.toolbarHeight)
        let previewMinimum = min(Self.previewMinimum(for: usable), max(0, usable - bars))

        guard let panel else {
            preview = max(restingPreview, previewMinimum)
            timeline = max(0, usable - bars - preview - Self.toolbarHeight)
            toolbar = Self.toolbarHeight
            self.panel = 0
            panelPresentation = .inline
            panelIsCompressed = false
            return
        }
        toolbar = 0
        let panelHeight = panel.height(for: usable)

        if panel == .full, heightClass == .veryCompact {
            // A sheet over the editor: the preview shrinks to its minimum so the sheet's tallest
            // height never covers it. It floats over the editor, so it is sized from the screen
            // and stays put when the keyboard comes up inside it.
            let full = Self.sheetBudget(stable: stable, bars: bars)
            preview = full.preview
            timeline = full.timeline
            self.panel = 0
            panelPresentation = .sheet(medium: min(EditorPanelSize.full.height(for: stable), full.large), large: full.large)
            panelIsCompressed = false
            return
        }

        panelPresentation = .inline
        if keyboardIsUp {
            // The keyboard owns the lower part. The video shrinks to what still shows the text, the
            // timeline steps aside, and the panel sits over the keyboard with what it needs to type.
            let room = max(0, usable - bars)
            let floor = min(Self.previewMinimumWithKeyboard(for: usable), room)
            let fitting = min(panelHeight, max(0, room - floor))
            self.panel = fitting
            preview = room - fitting
            timeline = 0
            panelIsCompressed = fitting < panelHeight
            return
        }
        let available = max(0, usable - bars - panelHeight)
        var needed: CGFloat = 0
        if panel != .full {
            needed = heightClass.rulerHeight + heightClass.panelMainTrackHeight + Self.timelineBottomPadding
            if panelFocusesLane { needed += Self.laneGap + heightClass.laneHeight }
        }
        let preview = min(restingPreview, max(previewMinimum, available - needed))
        if preview <= available {
            self.preview = max(preview, previewMinimum)
            timeline = max(0, available - self.preview)
            self.panel = panelHeight
            panelIsCompressed = false
        } else {
            // Not even the smallest preview fits beside the panel: the panel gives way and scrolls.
            self.preview = previewMinimum
            timeline = 0
            self.panel = max(0, usable - bars - previewMinimum)
            panelIsCompressed = true
        }
    }

    /// What the editor behind a sheet panel gets, from the screen's height.
    private static func sheetBudget(stable: CGFloat, bars: CGFloat) -> (preview: CGFloat, timeline: CGFloat, large: CGFloat) {
        let minimum = min(previewMinimum(for: stable), max(0, stable - bars))
        return (minimum, max(0, stable - bars - minimum), max(0, stable - minimum))
    }

    /// Whether the timeline has room to show anything.
    var showsTimeline: Bool { timeline >= heightClass.rulerHeight + 20 }
}
