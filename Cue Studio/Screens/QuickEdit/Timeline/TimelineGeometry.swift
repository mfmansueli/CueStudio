//
//  TimelineGeometry.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where everything goes on the timeline, in content points: x is edited seconds times
/// `pointsPerSecond` (zero is the start of the video, under the playhead when it's at the start),
/// y is from the top of the timeline. Pure, so the layout is tested without a screen.
///
/// - The ruler on top, then the video track (frames over a waveform), then the tracks under it: photos and videos over the
///   take (with their frames; short spaces between supports marked), Blur areas (when there are any; what's left unchecked
///   hatched), texts, captions, music and voice-over. Each track sits on a strip that stays on screen, with its icon in a
///   gutter on the left; an empty one says what a tap on it does ("Tap to add text"). Tapping a track opens its tools.
/// - Collapsed (`TimelineTrackChoice`), only the current track shows under the video, ▾ beside its icon; ▾ brings every track
///   out in place, ▴ puts them away. Every track under the video is as tall (`EditorHeightClass.laneHeight`); out, every one
///   shows, shrunk to `Input.openLaneHeight` (`EditorLayout`). A finger dragging the timeline up or down lays every track out
///   between the two (`Input.reveal`), the others fading in.
/// - With a panel open the timeline is compact: the video track shrinks to 40 pt and the track the
///   panel is about (if any) comes up under the ruler, alone with the video and as tall as it.
/// - The picked item has a yellow outline and handles (16 pt on a clip, 12 on a track item, held
///   from 32 pt; a clip's reach grows into the clip, never over its neighbour); everything else dims.
/// - The cover sits before the start, and a "+" after the end adds a clip.
nonisolated struct TimelineGeometry: Equatable, Sendable {
    /// What the timeline shows, read from the edit.
    struct Input: Equatable, Sendable {
        var duration: TimeInterval
        var clips: [ClipInput] = []
        var texts: [ItemInput] = []
        var media: [ItemInput] = []
        /// Blur areas, once per showing.
        var blurs: [ItemInput] = []
        var captions: [ItemInput] = []
        /// Captions show in the video (the lines can exist while hidden).
        var showsCaptions = true
        var music: [ItemInput] = []
        var voiceOvers: [ItemInput] = []
        /// A voice-over being recorded, in edited seconds.
        var recording: TimeSpan?
        /// Pauses to review (the Pauses panel), on the video track.
        var pauses: [PauseInput] = []
        var selection: EditorSelection?
        /// The cut picked to choose its transition (named by the clip that starts there).
        var selectedJoin: UUID?
        var panelIsOpen = false
        var focusedLane: TimelineLane?
        /// The tracks whose tools are open on the toolbar (their strips light up).
        var activeLanes: Set<TimelineLane> = []
        /// The current track and whether every track is out; nil shows every track, with no ▾.
        var tracks: TimelineTrackChoice?
        var heightClass: EditorHeightClass = .regular
        /// How tall each track is while every track is out (`EditorLayout.openLaneHeight`); nil: as tall as one alone.
        var openLaneHeight: CGFloat?
        /// A finger dragging the timeline up or down, or ▾ settling (`EditorLayout.timelineReveal`): how far out every track
        /// is, 0 the current track alone and 1 every track out. Nil while it rests (and with a panel open).
        var reveal: CGFloat?
        var pointsPerSecond: CGFloat = TimelineGeometry.basePointsPerSecond
        /// The music's beats the playhead and the handles stick to (Beats › Snap to beats); empty when off.
        var beatSnaps: [TimeInterval] = []
    }

    struct ClipInput: Equatable, Sendable {
        var id: UUID
        /// Edited seconds where it starts, and how long it plays.
        var start: TimeInterval
        var duration: TimeInterval
        /// Its stretch of its recording.
        var sourceStart: TimeInterval
        var sourceEnd: TimeInterval
        var speed: Double
        /// Nil: the take itself.
        var sourceID: UUID?
        /// "1.5×", "Push in", "Muted" (joined), or nil.
        var badge: String?
        /// How the cut before it plays.
        var transition: EditTransition = .hardCut
        /// Rotate, Mirror and Crop: its frames show as the video does.
        var orientation: ClipOrientation = .identity
    }

    struct ItemInput: Equatable, Sendable {
        var id: UUID
        /// Edited seconds.
        var span: TimeSpan
        var label: String
        /// Edited seconds of its keyframes.
        var keyframes: [TimeInterval] = []
        /// Edited seconds of its beats (music from Files).
        var beats: [TimeInterval] = []
        /// Locked in place (`TakeEdit.lockedLayers`): no handles, a lock drawn on it.
        var isLocked = false
        /// A photo or video: what its frames are drawn from.
        var strip: MediaStrip?
        /// A Blur area: where it's left unchecked (edited seconds), hatched on its bar.
        var warnings: [TimeSpan] = []
        /// What a tap picks when the bar is one showing of something that shows several times (a Blur area on a clip and
        /// its copy): that thing's id; nil: the bar's own.
        var owner: UUID?
    }

    /// What a photo's or video's bar shows: its frames, piece by piece (each starting at its second of the file), how it shows.
    struct MediaStrip: Equatable, Sendable {
        var fileName: String
        var isVideo: Bool
        var pieces: [MediaPiece]
        var layout: MediaLayout
    }

    /// A short space between two supports of the split screen (the main video has the whole frame there for a moment), marked
    /// on the media track: a tap picks the support after it, whose tools close it.
    struct Gap: Equatable, Sendable {
        var id: UUID
        var frame: CGRect
    }

    /// Spaces shorter than this between two supports are marked: longer ones are plainly on purpose.
    static let markedGap: TimeInterval = 0.5

    struct PauseInput: Equatable, Sendable {
        var id: UUID
        /// Edited seconds.
        var span: TimeSpan
        /// Marked to be removed (yellow) or kept (gray).
        var isMarked: Bool
    }

    enum ItemKind: String, Equatable, Sendable {
        case text, media, caption, music, voiceOver, recording, blur

        var lane: TimelineLane {
            switch self {
            case .media: .media
            case .blur: .blur
            case .text: .text
            case .caption: .captions
            case .music: .music
            case .voiceOver, .recording: .voiceOver
            }
        }
    }

    struct LaneFrame: Equatable, Sendable {
        var lane: TimelineLane
        var y: CGFloat
        var height: CGFloat
        /// Under 1 while it comes out or goes away under a finger (`Input.reveal`): its strip, icon and items fade with it.
        var opacity: CGFloat = 1
    }

    struct Clip: Equatable, Sendable {
        var id: UUID
        var frame: CGRect
        /// Frames on top, the waveform under them.
        var thumbnailHeight: CGFloat
        var waveformHeight: CGFloat
        var sourceStart: TimeInterval
        var sourceEnd: TimeInterval
        var speed: Double
        var sourceID: UUID?
        var badge: String?
        var isSelected: Bool
        var isDimmed: Bool
        /// "4.2s", shown while it's picked.
        var duration: TimeInterval
        var orientation: ClipOrientation = .identity
    }

    struct Item: Equatable, Sendable {
        var kind: ItemKind
        var id: UUID
        var frame: CGRect
        var label: String
        var isSelected: Bool
        var isDimmed: Bool
        /// Keyframe diamonds, from the item's left edge.
        var keyframeOffsets: [CGFloat]
        /// Beat ticks (music), from the item's left edge.
        var beatOffsets: [CGFloat] = []
        var isLocked = false
        /// A photo or video's frames.
        var strip: MediaStrip?
        /// A Blur area's unchecked stretches, from the item's left edge.
        var warningRanges: [ClosedRange<CGFloat>] = []
        /// What a tap on it picks (`ItemInput.owner`), else its own id.
        var owner: UUID?
        /// Its track's (`LaneFrame.opacity`).
        var opacity: CGFloat = 1

        /// The id a tap picks.
        var pickedID: UUID { owner ?? id }
    }

    struct Pause: Equatable, Sendable {
        var id: UUID
        var frame: CGRect
        var isMarked: Bool
    }

    /// The mark in the middle of a cut: tap it to pick the cut's transition.
    struct Join: Equatable, Sendable {
        /// The clip that starts at the cut.
        var id: UUID
        var frame: CGRect
        /// Where a finger takes hold of it.
        var hitFrame: CGRect
        var transition: EditTransition
        var isSelected: Bool
    }

    /// What a tap lands on.
    enum Hit: Equatable, Sendable {
        case clip(UUID)
        case item(ItemKind, UUID)
        case pause(UUID)
        case join(UUID)
        /// A short space before the support `UUID` (`Gap`).
        case gap(UUID)
        case cover
        case addClip
        /// A track's strip or gutter, or its hint: opens the track's tools.
        case lane(TimelineLane)
        /// ▾ or ▴ beside the current track's icon: every track out, or put away.
        case trackChooser
    }

    /// ▾ (▴ while every track is out) beside the current track's icon, and where a finger reaches it.
    struct Chooser: Equatable, Sendable {
        var lane: TimelineLane
        var isExpanded: Bool
        /// How far ▾ has turned to ▴: 0 or 1 at rest, in between while a finger drags (`Input.reveal`).
        var turn: CGFloat
        /// Across in the timeline's own width (the gutter stays put), down in the content: the icon's column and the start of
        /// the strip, with the space above the track and, collapsed, the room under it, so it is `chooserReach` square at least.
        var hitFrame: CGRect
    }

    /// A handle being dragged: an end of a clip or of a track item.
    enum HandleTarget: Equatable, Sendable {
        case clip(UUID, TrimHandle)
        case item(ItemKind, UUID, TrimHandle)
        /// The picked item's body: dragging it moves the item in time, keeping its length (CapCut's grammar).
        case move(ItemKind, UUID)

        var edge: TrimHandle {
            switch self {
            case .clip(_, let edge), .item(_, _, let edge): edge
            case .move: .start
            }
        }
    }

    struct Handle: Equatable, Sendable {
        var target: HandleTarget
        /// What shows: a yellow tab against the item.
        var frame: CGRect
        /// Where a finger takes hold of it: at least `handleReach` wide.
        var hitFrame: CGRect
    }

    /// What an empty track says about a tap on it. Its x follows the visible area (it stays at the
    /// left edge of the strip while the start of the video is scrolled away).
    struct Ghost: Equatable, Sendable {
        var lane: LaneFrame
        var label: String
        var target: Hit
    }

    // MARK: - Constants

    /// Points per second at zoom 1.
    static let basePointsPerSecond: CGFloat = 44
    static let zoomRange: ClosedRange<CGFloat> = 0.35...5
    static let clipHandleWidth: CGFloat = 16
    static let itemHandleWidth: CGFloat = 12
    /// The least a handle can be held from.
    static let handleReach: CGFloat = 32
    /// The gutter with each track's icon (and ▾ beside the current one's, the whole cell its button), and where its strip
    /// starts and ends (from the right edge of the timeline). Items scroll under the gutter.
    static let gutterWidth: CGFloat = 46
    static let stripLeading: CGFloat = 48
    static let stripTrailing: CGFloat = 8
    /// Where an empty track's hint starts, from the left edge of the timeline.
    static let hintLeading: CGFloat = 58
    /// The least ▾ is reached from, across and down.
    static let chooserReach: CGFloat = 44
    static let coverWidth: CGFloat = 50
    static let coverGap: CGFloat = 20
    static let addSize: CGFloat = 32
    static let addGap: CGFloat = 14
    /// A cut's mark, and the least room each clip beside it needs for it to show.
    static let joinSize: CGFloat = 20
    static let joinRoom: CGFloat = 26
    /// The voice-over being recorded has no id of its own yet.
    static let recordingID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

    // MARK: - Output

    let input: Input
    let lanes: [LaneFrame]
    let clips: [Clip]
    let items: [Item]
    let pauses: [Pause]
    let joins: [Join]
    let gaps: [Gap]
    let handles: [Handle]
    /// The picked track item's body, held to move it (never drawn: the item itself shows).
    let bodies: [Handle]
    let ghosts: [Ghost]
    /// ▾ or ▴, when the timeline can collapse to one track.
    let chooser: Chooser?
    let coverFrame: CGRect
    let addFrame: CGRect
    let contentWidth: CGFloat
    let contentHeight: CGFloat

    var pointsPerSecond: CGFloat { input.pointsPerSecond }
    var isCompact: Bool { input.panelIsOpen }
    /// Where the tracks start, under the ruler: the ruler stays put while they scroll up and down.
    var tracksTop: CGFloat { isCompact ? Self.compactRulerHeight : input.heightClass.rulerHeight }

    func lane(_ lane: TimelineLane) -> LaneFrame? {
        lanes.first { $0.lane == lane }
    }

    func x(for time: TimeInterval) -> CGFloat {
        CGFloat(time) * input.pointsPerSecond
    }

    func time(for x: CGFloat) -> TimeInterval {
        TimeInterval(x / max(0.001, input.pointsPerSecond))
    }

    // MARK: - Building

    init(_ input: Input) {
        self.input = input
        let pps = input.pointsPerSecond
        let compact = input.panelIsOpen
        let hasMusic = !input.music.isEmpty
        let hasVoice = !input.voiceOvers.isEmpty || input.recording != nil

        let (order, chosen) = Self.laneOrder(input)
        // A picked cut is between clips: it dims nothing.
        let selection = input.selection?.joinID == nil ? input.selection : nil
        let (lanes, spacing, height) = Self.frames(of: order, input)
        self.lanes = lanes
        contentHeight = height
        let isExpanded = input.tracks?.isExpanded == true
        let turn = Self.reveal(of: input) ?? (isExpanded ? 1 : 0)
        chooser = chosen.flatMap { chosen in
            lanes.first { $0.lane == chosen }.map { Self.chooser(beside: $0, isExpanded: isExpanded, turn: turn, spacing: spacing) }
        }
        contentWidth = CGFloat(input.duration) * pps

        let main = lanes.first { $0.lane == .main } ?? LaneFrame(lane: .main, y: 0, height: 0)
        let waveform: CGFloat = compact ? 10 : 14
        var handles: [Handle] = []

        clips = input.clips.map { clip in
            let x = CGFloat(clip.start) * pps
            let width = CGFloat(clip.duration) * pps
            let isSelected = selection == .clip(clip.id)
            if isSelected {
                let inward = (width - 2) / 2
                handles.append(Self.handle(
                    .clip(clip.id, .start), x: x - Self.clipHandleWidth + 1, width: Self.clipHandleWidth, lane: main, inward: inward
                ))
                handles.append(Self.handle(.clip(clip.id, .end), x: x + width - 1, width: Self.clipHandleWidth, lane: main, inward: inward))
            }
            return Clip(
                id: clip.id,
                frame: CGRect(x: x + 1, y: main.y, width: max(3, width - 2), height: main.height),
                thumbnailHeight: max(0, main.height - waveform),
                waveformHeight: waveform,
                sourceStart: clip.sourceStart, sourceEnd: clip.sourceEnd, speed: clip.speed, sourceID: clip.sourceID,
                badge: clip.badge,
                isSelected: isSelected,
                isDimmed: selection != nil && !isSelected,
                duration: clip.duration,
                orientation: clip.orientation
            )
        }

        // A cut's mark, always within reach (tapping it opens Transitions, CapCut's grammar), except at the picked clip's own
        // edges (its handles sit there) and while Pauses is open.
        var joins: [Join] = []
        let picked = selection?.clipID.flatMap { id in input.clips.firstIndex { $0.id == id } }
        if input.pauses.isEmpty {
            for (index, clip) in input.clips.enumerated() where index > 0 && index != picked && index - 1 != picked {
                let before = CGFloat(input.clips[index - 1].duration) * pps
                guard before >= Self.joinRoom, CGFloat(clip.duration) * pps >= Self.joinRoom else { continue }
                let x = CGFloat(clip.start) * pps
                let size = Self.joinSize
                let frame = CGRect(x: x - size / 2, y: main.y + (main.height - size) / 2, width: size, height: size)
                let reach = Self.handleReach
                joins.append(Join(
                    id: clip.id, frame: frame,
                    hitFrame: CGRect(x: x - reach / 2, y: main.y, width: reach, height: main.height),
                    transition: clip.transition, isSelected: input.selectedJoin == clip.id
                ))
            }
        }
        self.joins = joins

        pauses = input.pauses.map { pause in
            Pause(
                id: pause.id,
                frame: CGRect(
                    x: CGFloat(pause.span.start) * pps, y: main.y,
                    width: max(8, CGFloat(pause.span.duration) * pps), height: main.height
                ),
                isMarked: pause.isMarked
            )
        }

        var items: [Item] = []
        var bodies: [Handle] = []
        func add(_ kind: ItemKind, _ inputs: [ItemInput]) {
            guard let lane = lanes.first(where: { $0.lane == kind.lane }) else { return }
            for item in inputs {
                let x = CGFloat(item.span.start) * pps
                let width = max(4, CGFloat(item.span.duration) * pps - 2)
                let id = item.id
                let isSelected = Self.isSelected(kind, item.owner ?? id, selection)
                items.append(Item(
                    kind: kind, id: id,
                    frame: CGRect(x: x, y: lane.y, width: width, height: lane.height),
                    label: item.label,
                    isSelected: isSelected,
                    isDimmed: selection != nil && !isSelected,
                    keyframeOffsets: item.keyframes.map { CGFloat($0 - item.span.start) * pps },
                    beatOffsets: item.beats.map { CGFloat($0 - item.span.start) * pps },
                    isLocked: item.isLocked,
                    strip: item.strip,
                    warningRanges: item.warnings.compactMap { warning in
                        let from = max(0, CGFloat(warning.start - item.span.start) * pps)
                        let to = min(width, CGFloat(warning.end - item.span.start) * pps)
                        return to > from ? from...max(from + 2, to) : nil
                    },
                    owner: item.owner,
                    opacity: lane.opacity
                ))
                // A picked item trims by its handles and moves by its body; a locked one keeps its place. A Blur area stays on
                // what it covers: it trims, it doesn't move.
                if isSelected, !item.isLocked {
                    handles.append(Self.handle(.item(kind, id, .start), x: x - Self.itemHandleWidth, width: Self.itemHandleWidth, lane: lane))
                    handles.append(Self.handle(.item(kind, id, .end), x: x + width, width: Self.itemHandleWidth, lane: lane))
                    if kind != .blur {
                        let body = CGRect(x: x, y: lane.y, width: width, height: lane.height)
                        bodies.append(Handle(target: .move(kind, id), frame: body, hitFrame: body))
                    }
                }
            }
        }
        add(.text, input.texts)
        add(.media, input.media)
        add(.blur, input.blurs)
        if input.showsCaptions { add(.caption, input.captions) }
        add(.music, input.music)
        add(.voiceOver, input.voiceOvers)
        if let recording = input.recording, let lane = lanes.first(where: { $0.lane == .voiceOver }) {
            items.append(Item(
                kind: .recording, id: Self.recordingID,
                frame: CGRect(x: CGFloat(recording.start) * pps, y: lane.y, width: max(2, CGFloat(recording.duration) * pps), height: lane.height),
                label: String(localized: "Recording…"),
                isSelected: false, isDimmed: false, keyframeOffsets: []
            ))
        }
        self.items = items
        self.handles = handles
        self.bodies = bodies

        gaps = lanes.first { $0.lane == .media }.map { Self.gaps(between: input.media, on: $0, pointsPerSecond: pps) } ?? []

        var ghosts: [Ghost] = []
        if input.media.isEmpty, let lane = lanes.first(where: { $0.lane == .media }) {
            ghosts.append(Ghost(lane: lane, label: String(localized: "Tap to add a photo or video"), target: .lane(.media)))
        }
        if input.texts.isEmpty, let lane = lanes.first(where: { $0.lane == .text }) {
            ghosts.append(Ghost(lane: lane, label: String(localized: "Tap to add text"), target: .lane(.text)))
        }
        if !input.showsCaptions || input.captions.isEmpty, let lane = lanes.first(where: { $0.lane == .captions }) {
            let label = input.captions.isEmpty ? String(localized: "Tap to add captions") : String(localized: "Captions off")
            ghosts.append(Ghost(lane: lane, label: label, target: .lane(.captions)))
        }
        if !hasMusic, !hasVoice, let lane = lanes.first(where: { $0.lane == .audio }) {
            ghosts.append(Ghost(lane: lane, label: String(localized: "Tap to add music or voice-over"), target: .lane(.audio)))
        }
        self.ghosts = ghosts

        coverFrame = CGRect(x: -(Self.coverWidth + Self.coverGap), y: main.y, width: Self.coverWidth, height: main.height)
        addFrame = CGRect(x: contentWidth + Self.addGap, y: main.y + (main.height - Self.addSize) / 2, width: Self.addSize, height: Self.addSize)
    }

    /// ▾ beside `frame`'s icon: the gutter's whole cell across, reached up to the track above, never into it, and down as far
    /// as the reach needs while nothing is under it.
    private static func chooser(beside frame: LaneFrame, isExpanded: Bool, turn: CGFloat, spacing: CGFloat) -> Chooser {
        let below = isExpanded ? spacing : max(spacing, chooserReach - frame.height - spacing)
        return Chooser(
            lane: frame.lane, isExpanded: isExpanded, turn: turn,
            hitFrame: CGRect(
                x: 0, y: frame.y - spacing, width: max(chooserReach, gutterWidth), height: spacing + frame.height + below
            )
        )
    }

    /// The short spaces between supports of the split screen (`markedGap`), on the media track.
    private static func gaps(between media: [ItemInput], on lane: LaneFrame, pointsPerSecond pps: CGFloat) -> [Gap] {
        let supports = media.filter { $0.strip?.layout == .split }.sorted { $0.span.start < $1.span.start }
        return zip(supports, supports.dropFirst()).compactMap { before, after in
            let gap = after.span.start - before.span.end
            guard gap > 0.01, gap < markedGap else { return nil }
            let middle = CGFloat(before.span.end + gap / 2) * pps
            let width = max(10, CGFloat(gap) * pps)
            return Gap(id: after.id, frame: CGRect(x: middle - width / 2, y: lane.y, width: width, height: lane.height))
        }
    }

    /// The tracks, top to bottom, and the one ▾ sits beside: with a panel about one track open, that track over the video (no
    /// ▾); collapsed, the video and the current track; else every track (`lanes`).
    private static func laneOrder(_ input: Input) -> (lanes: [TimelineLane], chooser: TimelineLane?) {
        if input.panelIsOpen, let focus = input.focusedLane { return ([focus, .main], nil) }
        let all = lanes(
            hasBlurs: !input.blurs.isEmpty, hasMusic: !input.music.isEmpty, hasVoice: !input.voiceOvers.isEmpty || input.recording != nil
        )
        guard let tracks = input.tracks else { return (all, nil) }
        // Under a finger every track is laid out, on its way out or away (`revealingFrames`).
        if reveal(of: input) != nil { return (all, tracks.shown(in: all)) }
        return (tracks.lanes(from: all), tracks.shown(in: all))
    }

    /// How far out every track is under a finger (`Input.reveal`), within 0…1 (the timeline stretches past either end, the
    /// tracks don't); nil at rest, with a panel open or with no current track.
    private static func reveal(of input: Input) -> CGFloat? {
        guard let reveal = input.reveal, !input.panelIsOpen, input.tracks != nil else { return nil }
        return min(1, max(0, reveal))
    }

    /// Every track, top to bottom: the video, then photos and videos, Blur areas (when there are any), texts, captions, and
    /// music and voice-over (or the shortcut to add them). Photos and videos, texts and captions are there empty too, saying
    /// how to add the first.
    static func lanes(hasBlurs: Bool, hasMusic: Bool, hasVoice: Bool) -> [TimelineLane] {
        var lanes: [TimelineLane] = [.main, .media]
        if hasBlurs { lanes.append(.blur) }
        lanes += [.text, .captions]
        if hasMusic { lanes.append(.music) }
        if hasVoice { lanes.append(.voiceOver) }
        if !hasMusic, !hasVoice { lanes.append(.audio) }
        return lanes
    }

    /// Where each of `order` sits, top to bottom under the ruler, the room between them, and how tall they are in all. Every
    /// track under the video is as tall: out (not one under a panel about it), the height the editor gave them; under a panel,
    /// no taller than the video track.
    private static func frames(of order: [TimelineLane], _ input: Input) -> (lanes: [LaneFrame], spacing: CGFloat, height: CGFloat) {
        if let reveal = reveal(of: input), let current = input.tracks?.shown(in: order) {
            return revealingFrames(of: order, current: current, reveal: reveal, input)
        }
        let heightClass = input.heightClass
        let compact = input.panelIsOpen
        let isEveryTrack = !(compact && input.focusedLane != nil) && input.tracks?.isExpanded != false
        var trackHeight = isEveryTrack ? input.openLaneHeight ?? heightClass.laneHeight : heightClass.laneHeight
        if compact { trackHeight = min(trackHeight, heightClass.panelLaneHeight) }
        let spacing = laneSpacing(compact: compact, everyTrack: isEveryTrack)
        var lanes: [LaneFrame] = []
        var y: CGFloat = compact ? compactRulerHeight : heightClass.rulerHeight
        for lane in order {
            let height = lane == .main ? mainHeight(heightClass, compact: compact) : trackHeight
            lanes.append(LaneFrame(lane: lane, y: y, height: height))
            y += height + spacing
        }
        return (lanes, spacing, y)
    }

    /// Every track `reveal` of the way from where it rests collapsed (where the current track sits under the video, the others
    /// with it, unseen) to where it sits out, as tall as it is there; the current track shows throughout, the others fade in
    /// from 15% to 65% of the way. At 0 and 1 the frames are the collapsed and the expanded ones, so letting go never jumps.
    private static func revealingFrames(
        of order: [TimelineLane], current: TimelineLane, reveal: CGFloat, _ input: Input
    ) -> (lanes: [LaneFrame], spacing: CGFloat, height: CGFloat) {
        let heightClass = input.heightClass
        func mix(_ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * reveal }
        let closedSpacing = laneSpacing(compact: false, everyTrack: false)
        let openSpacing = laneSpacing(compact: false, everyTrack: true)
        let openHeight = input.openLaneHeight ?? heightClass.laneHeight
        let top = heightClass.rulerHeight
        let main = heightClass.mainTrackHeight
        let closedY = top + main + closedSpacing
        let fade = min(1, max(0, (reveal - 0.15) / 0.5))
        let spacing = mix(closedSpacing, openSpacing)
        var lanes: [LaneFrame] = []
        var openY = top
        var bottom = top
        for lane in order {
            guard lane != .main else {
                lanes.append(LaneFrame(lane: .main, y: top, height: main))
                openY += main + openSpacing
                bottom = top + main
                continue
            }
            let frame = LaneFrame(
                lane: lane, y: mix(closedY, openY), height: mix(heightClass.laneHeight, openHeight), opacity: lane == current ? 1 : fade
            )
            lanes.append(frame)
            openY += openHeight + openSpacing
            bottom = max(bottom, frame.y + frame.height)
        }
        return (lanes, spacing, bottom + spacing)
    }

    /// The video track's own height, shorter while a panel is open.
    private static func mainHeight(_ heightClass: EditorHeightClass, compact: Bool) -> CGFloat {
        compact ? heightClass.panelMainTrackHeight : heightClass.mainTrackHeight
    }

    /// The room between tracks (and under the last): tighter under a panel and with every track out, so more of them fit.
    private static func laneSpacing(compact: Bool, everyTrack: Bool) -> CGFloat {
        compact || everyTrack ? 6 : 8
    }

    /// The ruler's room while a panel is open.
    private static let compactRulerHeight: CGFloat = 22

    /// What `lanes` take with every track out and nothing open, each track `laneHeight` tall, from the top of the ruler to the
    /// room under the last.
    static func openHeight(of lanes: [TimelineLane], heightClass: EditorHeightClass, laneHeight: CGFloat) -> CGFloat {
        let spacing = laneSpacing(compact: false, everyTrack: true)
        return lanes.reduce(heightClass.rulerHeight) { total, lane in
            total + (lane == .main ? heightClass.mainTrackHeight : laneHeight) + spacing
        }
    }

    /// How tall each track is with every track out so `lanes` fit in `room`: as tall as one alone at most, `openLaneMinimum`
    /// at least (past that the timeline grows past `room`, `EditorLayout`).
    static func openLaneHeight(for lanes: [TimelineLane], heightClass: EditorHeightClass, room: CGFloat) -> CGFloat {
        let tracks = CGFloat(lanes.filter { $0 != .main }.count)
        guard tracks > 0 else { return heightClass.laneHeight }
        let spacing = laneSpacing(compact: false, everyTrack: true)
        let fixed = heightClass.rulerHeight + heightClass.mainTrackHeight + spacing
        let each = ((room - fixed) / tracks - spacing).rounded(.down)
        return min(heightClass.laneHeight, max(heightClass.openLaneMinimum, each))
    }

    /// What the timeline takes collapsed: the ruler, the video track and one track under it, every track as tall, so choosing
    /// another track, picking an item or music coming or going never moves the video.
    static func collapsedHeight(heightClass: EditorHeightClass) -> CGFloat {
        let spacing = laneSpacing(compact: false, everyTrack: false)
        return heightClass.rulerHeight + heightClass.mainTrackHeight + spacing + heightClass.laneHeight + spacing
    }

    private static func isSelected(_ kind: ItemKind, _ id: UUID, _ selection: EditorSelection?) -> Bool {
        switch (kind, selection) {
        case (.text, .text(let picked)?), (.media, .media(let picked)?), (.caption, .caption(let picked)?),
             (.music, .music(let picked)?), (.voiceOver, .voiceOver(let picked)?), (.blur, .blur(let picked)?):
            picked == id
        default: false
        }
    }

    /// A handle reached from at least `handleReach`. A track item's grows outward, so the item itself stays tappable and draggable.
    /// A clip's sits on the cut, over the neighbour: it grows into the picked clip (up to `inward`, half of it), so over the
    /// neighbour a finger finds only the handle it sees, and the rest of the neighbour is the neighbour's.
    private static func handle(_ target: HandleTarget, x: CGFloat, width: CGFloat, lane: LaneFrame, inward: CGFloat? = nil) -> Handle {
        let frame = CGRect(x: x, y: lane.y, width: width, height: lane.height)
        var extra = max(0, handleReach - width)
        if let inward { extra = min(extra, max(0, inward)) }
        let growsLeft = (target.edge == .start) == (inward == nil)
        let hitX = growsLeft ? x - extra : x
        let hit = CGRect(x: hitX, y: lane.y - 4, width: width + extra, height: lane.height + 8)
        return Handle(target: target, frame: frame, hitFrame: hit)
    }

    // MARK: - Hit testing

    /// The handle under `point`, if any: handles come first.
    func handle(at point: CGPoint) -> Handle? {
        handles.first { $0.hitFrame.contains(point) }
    }

    /// What a drag starting at `point` holds: a handle (trims), else the picked item's body (moves it).
    func dragTarget(at point: CGPoint) -> Handle? {
        handle(at: point) ?? bodies.first { $0.hitFrame.contains(point) }
    }

    /// What a tap at `point` lands on, after handles: the cover, the "+", a pause, a cut's mark, a
    /// track item, a clip. Nil is empty space (`laneHit` says whether it was on a track).
    func hit(at point: CGPoint) -> Hit? {
        if coverFrame.contains(point) { return .cover }
        if addFrame.insetBy(dx: -6, dy: -6).contains(point) { return .addClip }
        if let pause = pauses.first(where: { $0.frame.contains(point) }) { return .pause(pause.id) }
        if let gap = gaps.first(where: { $0.frame.insetBy(dx: -6, dy: 0).contains(point) }) { return .gap(gap.id) }
        if let join = joins.first(where: { $0.hitFrame.contains(point) }) { return .join(join.id) }
        // The picked item first, then from the top layer down.
        if let item = items.last(where: { $0.isSelected && $0.frame.contains(point) }) { return .item(item.kind, item.pickedID) }
        if let item = items.last(where: { $0.kind != .recording && $0.frame.contains(point) }) { return .item(item.kind, item.pickedID) }
        if let clip = clips.first(where: { $0.frame.insetBy(dx: -1, dy: 0).contains(point) }) { return .clip(clip.id) }
        return nil
    }

    /// The track under a tap on its strip or its gutter. `x` is where the finger is on the
    /// timeline's own width (not in the scrolled content), `width` that width. The video track has
    /// no strip.
    func laneHit(atViewportX x: CGFloat, y: CGFloat, viewportWidth width: CGFloat) -> Hit? {
        guard x >= 0, x <= width - Self.stripTrailing else { return nil }
        return lanes.first { $0.lane != .main && y >= $0.y && y <= $0.y + $0.height }.map { Hit.lane($0.lane) }
    }

    /// ▾ or ▴ under a tap at `x` across the timeline's own width and `y` down the content: it comes before the track and its items.
    func chooserHit(atViewportX x: CGFloat, y: CGFloat) -> Bool {
        chooser?.hitFrame.contains(CGPoint(x: x, y: y)) ?? false
    }

    // MARK: - Snapping

    /// Edited seconds the playhead and the handles stick to: cuts between clips, the start and end
    /// of the video, of every caption, text, photo or video, music and voice-over, keyframes, and the music's beats when they snap.
    var snapTimes: [TimeInterval] {
        var times: [TimeInterval] = [0, input.duration]
        times += input.clips.map(\.start)
        times += input.captions.flatMap { [$0.span.start, $0.span.end] }
        times += input.texts.flatMap { [$0.span.start, $0.span.end] + $0.keyframes }
        times += (input.media + input.blurs + input.music + input.voiceOvers).flatMap { [$0.span.start, $0.span.end] }
        times += input.beatSnaps
        return Array(Set(times)).sorted()
    }
}
