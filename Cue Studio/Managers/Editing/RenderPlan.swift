//
//  RenderPlan.swift
//  Cue Studio
//

import Foundation

/// Everything a drawing of an edit reads, worked out once from the edit and what it is drawn for (`EditRenderPurpose`): the
/// edit as drawn (for the editor's preview, its first and last clips grown to the whole recording, so a handle scrubs real
/// frames), where the edit as made starts and plays in that drawing, its transitions and zooms measured on the edit as made,
/// and the options. The composition is built from the plan alone (`EditedComposition.build(source:plan:)`), and the preview
/// keys its item on the plan (`item`), so what the player thinks it is showing and what is drawn can't drift apart.
nonisolated struct RenderPlan: Equatable, Sendable {
    /// The edit as drawn.
    let drawn: TakeEdit
    /// Where the edit as made starts in the drawing (seconds), and the pieces the growing put before its first one.
    let leadIn: TimeInterval
    let leadPieces: Int
    /// Where the edit as made plays in the drawing; music is placed on it. Nil: the whole drawing (the edit as it is).
    let window: TimeSpan?
    /// The transitions and each piece's zoom, measured on the edit as made and placed where the drawing plays them.
    let transitions: [TransitionWindow]
    let zooms: [ZoomWindow?]
    let options: EditedComposition.Options

    init(_ made: TakeEdit, options: EditedComposition.Options) {
        let grows = options.reachesWholeRecording
        var drawn = made
        if grows { drawn.timeline = made.timeline.reachable }
        self.drawn = drawn
        leadIn = grows ? made.timeline.reachableLeadIn : 0
        leadPieces = grows ? made.timeline.reachableLeadPieces : 0
        window = grows ? TimeSpan(start: leadIn, end: leadIn + made.editedDuration) : nil
        transitions = EditedComposition.transitionWindows(of: made.timeline, reachesWholeRecording: grows)
        zooms = EditedComposition.zoomWindows(of: made.timeline, reachesWholeRecording: grows)
        self.options = options
    }

    init(_ made: TakeEdit, purpose: EditRenderPurpose) {
        self.init(made, options: purpose.options)
    }

    /// What makes the preview need a new item (`QuickEditPlayer`): all of the plan but where the handles are, which only moves
    /// the window the item plays, unless something drawn is measured on them.
    var item: Item { Item(self) }

    /// A preview item's identity: the drawn edit without its timeline, the pieces it plays (seamless ones as one), each clip's
    /// sound, zoom, steadiness and look, the transitions and zooms where they play, and, only when they read it, where the
    /// edit starts: music (placed on the edit's own seconds) and a look that moves with time (grain counts from the edit's
    /// start). Not the curved sound's rendering, which the player switches on its own.
    struct Item: Equatable, Sendable {
        let recipe: TakeEdit
        let spans: [TimeSpan]
        /// One per span: the recording it is of (nil: the take). Two clips of the same seconds of different recordings,
        /// swapped, are new pieces.
        let sources: [UUID?]
        /// One per span: pieces at different speeds never join.
        let speeds: [Double]
        /// One per span: a curved piece's curve (its timing is new pieces).
        let curves: [SpeedCurve?]
        let transitions: [TransitionWindow]
        let zooms: [ZoomWindow?]
        /// Each clip's sound, zoom and steadiness (its volume, mute, pitch, zoom and strength, Stabilize).
        let pieceSettings: [[Double]]
        /// What each clip changes of the take's look (Adjust, Filters, Background).
        let clipLooks: [ClipLook?]
        /// Where the edit plays in the drawing, when music is placed on it.
        let musicWindow: TimeSpan?
        /// Where the edit starts in the drawing, when a look counts its grain from there.
        let lookClock: TimeInterval?

        init(_ plan: RenderPlan) {
            var recipe = plan.drawn
            recipe.timeline = Self.blankTimeline
            recipe.suggestions = []
            // The cover is drawn apart from the video.
            recipe.cover = nil
            self.recipe = recipe
            let drawn = plan.drawn.timeline
            var spans: [TimeSpan] = []
            var sources: [UUID?] = []
            var speeds: [Double] = []
            var curves: [SpeedCurve?] = []
            for (index, segment) in drawn.segments.enumerated() {
                if drawn.isSeamless(index) {
                    spans[spans.count - 1].end = segment.sourceEnd
                } else {
                    spans.append(segment.span)
                    sources.append(segment.sourceID)
                    speeds.append(segment.speed)
                    curves.append(segment.speedCurve)
                }
            }
            self.spans = spans
            self.sources = sources
            self.speeds = speeds
            self.curves = curves
            transitions = plan.transitions
            zooms = plan.zooms
            pieceSettings = drawn.segments.map { segment in
                [
                    segment.volume, segment.isMuted ? 1 : 0, segment.keepsPitch ? 1 : 0,
                    Double(SectionZoom.allCases.firstIndex { $0 == segment.zoom } ?? -1), segment.zoomAmount,
                    Double(StabilizationLevel.allCases.firstIndex { $0 == segment.stabilization } ?? -1),
                ]
            }
            clipLooks = drawn.segments.map(\.look)
            musicWindow = plan.drawn.music.isEmpty ? nil : plan.window
            lookClock = Self.movesWithTime(plan.drawn) ? plan.leadIn : nil
        }

        private static let blankTimeline = EditTimeline(sourceDuration: 0)

        /// Whether a look the edit draws changes from frame to frame (a filter's grain).
        private static func movesWithTime(_ edit: TakeEdit) -> Bool {
            let filters = [edit.filter] + edit.timeline.segments.compactMap { $0.look?.filter }
            return filters.contains { (FilterTexture.texture(for: $0)?.grain ?? 0) > 0 }
        }
    }
}
