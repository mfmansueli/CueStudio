//
//  EditorLayout.swift
//  Cue Studio
//

import CoreGraphics

/// The editor's vertical height budget, from the usable height under the navigation bar (Back · status · Done, the system's)
/// and above the bottom safe area: preview, player bar, timeline, and the toolbar or a panel. Nothing is placed at fixed
/// positions; every screen gets the same rules.
///
/// - Nothing open, the timeline collapsed (`TimelineTrackChoice`): the timeline takes just the ruler, the video track and one
///   track under it (every track is as tall), and the preview the rest.
/// - Nothing open, every track out: every track shows, none to scroll to (owner, 28/10/2026). They shrink so the video stays
///   at least as tall as everything under it (player bar, timeline and toolbar): `openLaneHeight`, from a track's own height
///   down to `openLaneMinimum`. When even that doesn't fit the half, the timeline grows past it and the video gives the room,
///   down to its minimum (only past that do the tracks scroll).
/// - A finger dragging the timeline up or down (`timelineReveal`): the timeline follows it between those two heights, the
///   video giving or taking back the room.
/// - A panel open (it replaces the toolbar): the preview keeps its size and the timeline gives up
///   its room. A panel that works on the timeline (all but the full ones) keeps the ruler and the
///   video track (and the track it is about) visible, taking that room from the preview down to its
///   minimum (30% of the height, at least 190 pt): the video never goes. Past that the panel gets
///   shorter and scrolls inside.
/// - With large text (Dynamic Type from xxLarge, which also makes a regular screen compact) a mini or
///   medium panel grows by up to half its height, from the preview down to its minimum: its labels and
///   controls take more lines, and the video is what can give.
/// - A full panel (Text style, Caption style), and Clean up, can be expanded: the preview goes down to its minimum
///   and the panel takes the rest, so its controls have room.
/// - On a very compact screen (iPhone SE) the full panels open as a sheet whose top stops under the
///   smallest preview, never over the video (expanded, the sheet is at that height).
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
    /// How tall each track is while every track is out (`TimelineGeometry.openLaneHeight`).
    let openLaneHeight: CGFloat
    /// What the timeline takes with nothing open: the current track alone, and every track out. A drag goes between the two.
    let collapsedTimeline: CGFloat
    let openTimeline: CGFloat
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
    /// How much taller a mini or medium panel may get with large text (`largeText`).
    static let largeTextPanelGrowth: CGFloat = 1.5

    /// The smallest the preview gets, whatever is open.
    static func previewMinimum(for usable: CGFloat) -> CGFloat {
        max(0.30 * usable, 190)
    }

    /// The smallest the video gets while the keyboard is up: enough to see the text being typed. The
    /// panel's header and field need the rest.
    static func previewMinimumWithKeyboard(for usable: CGFloat) -> CGFloat {
        max(0.22 * usable, 130)
    }

    /// A panel showing only its header, the field being typed in and its tabs (Text style while the keyboard is up), and the room
    /// above the keyboard. The video keeps the room the look's controls would have taken.
    static let typingPanelHeight: CGFloat = 180

    /// - Parameters:
    ///   - usableHeight: under the navigation bar, above the bottom safe area, and above the keyboard when it is up.
    ///   - stableHeight: the same without the keyboard; nil when there is none.
    ///   - panel: the open panel's size, if any.
    ///   - panelFocusesLane: the open panel is about one track (texts, captions, voice-over), which
    ///     then shows under the ruler too.
    ///   - largeText: Dynamic Type is large enough to make a regular screen compact.
    ///   - panelIsExpanded: an expandable panel (a full one, or Clean up) takes all the room but the smallest preview's.
    ///   - typesInHeaderField: while the keyboard is up the panel shows only its header, the field being typed in and its tabs
    ///     (Text style), so it takes just that and the video gets the rest.
    ///   - timelineLanes: every track of the edit (`TimelineGeometry.lanes`, a new edit's by default); with every track out
    ///     they share the timeline's room, and a panel opening keeps the preview at the size they left it.
    ///   - collapsesTimeline: the timeline shows the video track and the current track alone.
    ///   - timelineReveal: a finger is dragging the timeline: how far out every track is (0 the current track alone, 1 every
    ///     track out, a little past either end as it stretches). Nil when it rests.
    init(
        usableHeight: CGFloat, stableHeight: CGFloat? = nil, panel: EditorPanelSize? = nil,
        panelFocusesLane: Bool = false, largeText: Bool = false, panelIsExpanded: Bool = false, typesInHeaderField: Bool = false,
        timelineLanes: [TimelineLane] = TimelineGeometry.lanes(hasBlurs: false, hasMusic: false, hasVoice: false),
        collapsesTimeline: Bool = false, timelineReveal: CGFloat? = nil
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
        let previewMinimum = min(Self.previewMinimum(for: usable), max(0, usable - bars))
        // Collapsed, the tracks' own height, the preview giving it down to its minimum. Out, they share what leaves the video
        // at least as tall as everything under it.
        let trackRoom = usable - bars - Self.toolbarHeight - previewMinimum
        let halfRoom = max(0, usable / 2 - bars - Self.toolbarHeight)
        let openLane = TimelineGeometry.openLaneHeight(for: timelineLanes, heightClass: heightClass, room: halfRoom)
        openLaneHeight = openLane
        let collapsed = max(0, min(TimelineGeometry.collapsedHeight(heightClass: heightClass), trackRoom))
        let open = max(0, min(TimelineGeometry.openHeight(of: timelineLanes, heightClass: heightClass, laneHeight: openLane), trackRoom))
        collapsedTimeline = collapsed
        openTimeline = open
        let restingTimeline = if let reveal = timelineReveal {
            min(max(0, collapsed + (open - collapsed) * reveal), max(0, trackRoom))
        } else {
            collapsesTimeline ? collapsed : open
        }
        let restingPreview = max(0, usable - bars - restingTimeline - Self.toolbarHeight)

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
            let needed = typesInHeaderField ? min(panelHeight, Self.typingPanelHeight) : panelHeight
            let fitting = min(needed, max(0, room - floor))
            self.panel = fitting
            preview = room - fitting
            timeline = 0
            panelIsCompressed = fitting < panelHeight
            return
        }
        let room = max(0, usable - bars)
        if panelIsExpanded, room - previewMinimum > panelHeight {
            // Expanded: the video at its smallest, all the rest for the panel's controls.
            preview = previewMinimum
            timeline = 0
            self.panel = room - previewMinimum
            panelIsCompressed = false
            return
        }
        var needed: CGFloat = 0
        if panel != .full {
            needed = heightClass.rulerHeight + heightClass.panelMainTrackHeight + Self.timelineBottomPadding
            if panelFocusesLane { needed += Self.laneGap + heightClass.panelLaneHeight }
        }
        var inlineHeight = panelHeight
        if largeText, panel != .full {
            // Large text: the controls need more lines, so the panel grows (by half at most) and the video gives the room, down
            // to its minimum. The ruler and the video track stay.
            inlineHeight = max(panelHeight, min(panelHeight * Self.largeTextPanelGrowth, room - previewMinimum - needed))
        }
        let available = max(0, usable - bars - inlineHeight)
        let preview = min(restingPreview, max(previewMinimum, available - needed))
        if preview <= available {
            self.preview = max(preview, previewMinimum)
            timeline = max(0, available - self.preview)
            self.panel = inlineHeight
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
