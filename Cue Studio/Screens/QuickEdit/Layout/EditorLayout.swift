//
//  EditorLayout.swift
//  Cue Studio
//

import CoreGraphics

/// The editor's vertical height budget, from the usable height between the safe areas: top bar,
/// preview, player bar, timeline, and the toolbar or a panel. Nothing is placed at fixed positions;
/// every screen gets the same rules.
///
/// - Nothing open: the timeline takes 32% (184–300 pt) and the preview the rest.
/// - A panel open (it replaces the toolbar): the preview keeps its size and the timeline gives up
///   its room. A panel that works on the timeline (all but the full ones) keeps the ruler and the
///   video track (and the track it is about) visible, taking that room from the preview down to its
///   minimum (30% of the height, at least 190 pt): the video never goes. Past that the panel gets
///   shorter and scrolls inside.
/// - On a very compact screen (iPhone SE) the full panels open as a sheet whose top stops under the
///   smallest preview, never over the video.
nonisolated struct EditorLayout: Equatable, Sendable {
    /// How a panel is shown.
    enum PanelPresentation: Equatable, Sendable {
        /// Under the timeline, in place of the toolbar.
        case inline
        /// A sheet with two heights: `medium`, and `large`, whose top stays under the preview.
        case sheet(medium: CGFloat, large: CGFloat)
    }

    let usableHeight: CGFloat
    let heightClass: EditorHeightClass
    let topBar: CGFloat
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

    static let toolbarHeight: CGFloat = 64
    /// Room left under the last track.
    static let timelineBottomPadding: CGFloat = 8
    static let laneGap: CGFloat = 6

    /// The smallest the preview gets, whatever is open.
    static func previewMinimum(for usable: CGFloat) -> CGFloat {
        max(0.30 * usable, 190)
    }

    /// The timeline with nothing open.
    static func restingTimeline(for usable: CGFloat) -> CGFloat {
        EditorPanelSize.clamp(0.32 * usable, 184, 300)
    }

    /// - Parameters:
    ///   - usableHeight: between the safe areas.
    ///   - panel: the open panel's size, if any.
    ///   - panelFocusesLane: the open panel is about one track (texts, captions, voice-over), which
    ///     then shows under the ruler too.
    ///   - largeText: Dynamic Type is large enough to make a regular screen compact.
    init(usableHeight: CGFloat, panel: EditorPanelSize? = nil, panelFocusesLane: Bool = false, largeText: Bool = false) {
        let usable = max(0, usableHeight)
        let heightClass = EditorHeightClass(usableHeight: usable, largeText: largeText)
        self.usableHeight = usable
        self.heightClass = heightClass
        topBar = heightClass.topBarHeight
        playerBar = heightClass.playerBarHeight
        let bars = topBar + playerBar
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
            // height never covers it.
            preview = previewMinimum
            timeline = max(0, usable - bars - preview)
            self.panel = 0
            let large = max(0, usable - topBar - preview)
            panelPresentation = .sheet(medium: min(panelHeight, large), large: large)
            panelIsCompressed = false
            return
        }

        panelPresentation = .inline
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

    /// Whether the timeline has room to show anything.
    var showsTimeline: Bool { timeline >= heightClass.rulerHeight + 20 }
}
