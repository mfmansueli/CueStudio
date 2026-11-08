//
//  RenderPlan.swift
//  Cue Studio
//

import CoreGraphics
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
    /// The phrase zooms, measured on the edit as made and placed where the drawing plays them.
    let phraseZooms: [PhraseZoomWindow]
    /// Each piece's Animation, measured as its zoom.
    let animations: [ClipAnimationWindow?]
    let options: EditedComposition.Options

    init(_ edit: TakeEdit, options: EditedComposition.Options) {
        let grows = options.reachesWholeRecording
        // Punch in on cuts on the clips (`CutZoom`), so its zooms are drawn, measured and keyed like the creator's own.
        var made = edit
        if edit.cutZoom != nil { made.timeline = edit.punchedTimeline }
        var drawn = made
        if grows { drawn.timeline = made.timeline.reachable }
        self.drawn = drawn
        leadIn = grows ? made.timeline.reachableLeadIn : 0
        leadPieces = grows ? made.timeline.reachableLeadPieces : 0
        window = grows ? TimeSpan(start: leadIn, end: leadIn + made.editedDuration) : nil
        transitions = EditedComposition.transitionWindows(of: made.timeline, reachesWholeRecording: grows)
        zooms = EditedComposition.zoomWindows(of: made.timeline, reachesWholeRecording: grows)
        phraseZooms = PhraseZoomWindow.windows(of: made.phraseZooms, in: made.timeline, leadIn: leadIn)
        animations = EditedComposition.animationWindows(of: made.timeline, reachesWholeRecording: grows)
        self.options = options
    }

    init(_ made: TakeEdit, purpose: EditRenderPurpose) {
        self.init(made, options: purpose.options)
    }

    /// What makes the preview need a new item (`QuickEditPlayer`): all of the plan but where the handles are, which only moves
    /// the window the item plays, unless something drawn is measured on them.
    var item: Item { Item(self) }

    /// A preview item's identity: the drawn edit without its timeline, the pieces it plays (seamless ones as one), each clip's
    /// sound, zoom, steadiness, shape and look, the transitions, zooms and animations where they play, and where the edit plays in the drawing
    /// when music is placed on it. Not the curved sound's rendering, which the player switches on its own; and not where
    /// the edit starts for a filter's grain, which counts from there: grain is noise, drawn from an earlier start it looks
    /// the same, and a handle dragged under a grainy filter would otherwise rebuild the item at every move.
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
        let phraseZooms: [PhraseZoomWindow]
        let animations: [ClipAnimationWindow?]
        /// Each clip's sound, zoom, steadiness and shape (its volume, mute, pitch, fades, zoom and strength, Stabilize, Rotate,
        /// Mirror and Crop).
        let pieceSettings: [[Double]]
        /// What each clip changes of the take's look (Adjust, Filters, Background).
        let clipLooks: [ClipLook?]
        /// Each clip's voice effect.
        let voiceEffects: [VoiceEffectSetting?]
        /// Where the edit plays in the drawing, when music is placed on it.
        let musicWindow: TimeSpan?

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
            phraseZooms = plan.phraseZooms
            animations = plan.animations
            pieceSettings = drawn.segments.map { segment in
                let crop = segment.orientation.crop
                return [
                    segment.volume, segment.isMuted ? 1 : 0, segment.keepsPitch ? 1 : 0, segment.soundFadeIn, segment.soundFadeOut,
                    Double(SectionZoom.allCases.firstIndex { $0 == segment.zoom } ?? -1), segment.zoomAmount,
                    Double(StabilizationLevel.allCases.firstIndex { $0 == segment.stabilization } ?? -1),
                    Double(segment.quarterTurns), segment.isMirrored ? 1 : 0,
                    crop.map { Double($0.minX) } ?? -1, crop.map { Double($0.minY) } ?? -1, crop.map { Double($0.width) } ?? -1,
                    crop.map { Double($0.height) } ?? -1,
                ]
            }
            clipLooks = drawn.segments.map(\.look)
            voiceEffects = drawn.segments.map(\.voiceEffect)
            musicWindow = plan.drawn.music.isEmpty ? nil : plan.window
        }

        private static let blankTimeline = EditTimeline(sourceDuration: 0)
    }
}
