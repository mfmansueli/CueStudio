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
/// - The ruler on top, then the video track (frames over a waveform), then the tracks under it:
///   texts (and photos or videos over the take), captions, music and voice-over. An empty track
///   shows a dashed shortcut ("+ Add text", "+ Auto captions", "+ Add audio").
/// - With a panel open the timeline is compact: the video track shrinks to 40 pt and the track the
///   panel is about (if any) comes up under the ruler, alone with the video.
/// - The picked item has a yellow outline and handles (16 pt on a clip, 12 on a track item, held
///   from 32 pt); its track grows; everything else dims.
/// - The cover sits before the start, and a "+" after the end adds a clip.
nonisolated struct TimelineGeometry: Equatable, Sendable {
    /// What the timeline shows, read from the edit.
    struct Input: Equatable, Sendable {
        var duration: TimeInterval
        var clips: [ClipInput] = []
        var texts: [ItemInput] = []
        var media: [ItemInput] = []
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
        var panelIsOpen = false
        var focusedLane: TimelineLane?
        var heightClass: EditorHeightClass = .regular
        var pointsPerSecond: CGFloat = TimelineGeometry.basePointsPerSecond
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
    }

    struct ItemInput: Equatable, Sendable {
        var id: UUID
        /// Edited seconds.
        var span: TimeSpan
        var label: String
        /// Edited seconds of its keyframes.
        var keyframes: [TimeInterval] = []
    }

    struct PauseInput: Equatable, Sendable {
        var id: UUID
        /// Edited seconds.
        var span: TimeSpan
        /// Marked to be removed (yellow) or kept (gray).
        var isMarked: Bool
    }

    enum ItemKind: String, Equatable, Sendable {
        case text, media, caption, music, voiceOver, recording

        var lane: TimelineLane {
            switch self {
            case .text, .media: .text
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
    }

    struct Pause: Equatable, Sendable {
        var id: UUID
        var frame: CGRect
        var isMarked: Bool
    }

    /// What a tap lands on.
    enum Hit: Equatable, Sendable {
        case clip(UUID)
        case item(ItemKind, UUID)
        case pause(UUID)
        case cover
        case addClip
        case addText
        case captions
        case addAudio
    }

    /// A handle being dragged: an end of a clip or of a track item.
    enum HandleTarget: Equatable, Sendable {
        case clip(UUID, TrimHandle)
        case item(ItemKind, UUID, TrimHandle)

        var edge: TrimHandle {
            switch self {
            case .clip(_, let edge), .item(_, _, let edge): edge
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

    /// A dashed shortcut on an empty track. Its x follows the visible area (it sticks to the left
    /// edge while the start of the video is scrolled away); its width depends on its label.
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
    static let coverWidth: CGFloat = 50
    static let coverGap: CGFloat = 20
    static let addSize: CGFloat = 32
    static let addGap: CGFloat = 14
    /// A tap moves less than this.
    static let tapSlop: CGFloat = 4
    /// The voice-over being recorded has no id of its own yet.
    static let recordingID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

    // MARK: - Output

    let input: Input
    let lanes: [LaneFrame]
    let clips: [Clip]
    let items: [Item]
    let pauses: [Pause]
    let handles: [Handle]
    let ghosts: [Ghost]
    let coverFrame: CGRect
    let addFrame: CGRect
    let contentWidth: CGFloat
    let contentHeight: CGFloat

    var pointsPerSecond: CGFloat { input.pointsPerSecond }
    var isCompact: Bool { input.panelIsOpen }

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
        let heightClass = input.heightClass
        let compact = input.panelIsOpen
        let hasMusic = !input.music.isEmpty
        let hasVoice = !input.voiceOvers.isEmpty || input.recording != nil

        var others: [TimelineLane] = [.text, .captions]
        if hasMusic { others.append(.music) }
        if hasVoice { others.append(.voiceOver) }
        if !hasMusic, !hasVoice { others.append(.audio) }
        let order: [TimelineLane] = if compact, let focus = input.focusedLane {
            [focus, .main]
        } else {
            [.main] + others
        }
        let selectedLane = input.selection?.lane
        var lanes: [LaneFrame] = []
        var y: CGFloat = compact ? 22 : heightClass.rulerHeight
        for lane in order {
            let height: CGFloat = if lane == .main {
                compact ? heightClass.panelMainTrackHeight : heightClass.mainTrackHeight
            } else if !compact, lane == selectedLane {
                heightClass.selectedLaneHeight
            } else {
                heightClass.laneHeight
            }
            lanes.append(LaneFrame(lane: lane, y: y, height: height))
            y += height + (compact ? 6 : 8)
        }
        self.lanes = lanes
        contentHeight = y
        contentWidth = CGFloat(input.duration) * pps

        let main = lanes.first { $0.lane == .main } ?? LaneFrame(lane: .main, y: 0, height: 0)
        let waveform: CGFloat = compact ? 10 : 14
        var handles: [Handle] = []
        let selection = input.selection

        clips = input.clips.map { clip in
            let x = CGFloat(clip.start) * pps
            let width = CGFloat(clip.duration) * pps
            let isSelected = selection == .clip(clip.id)
            if isSelected {
                handles.append(Self.handle(.clip(clip.id, .start), x: x - Self.clipHandleWidth + 1, width: Self.clipHandleWidth, lane: main))
                handles.append(Self.handle(.clip(clip.id, .end), x: x + width - 1, width: Self.clipHandleWidth, lane: main))
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
                duration: clip.duration
            )
        }

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
        func add(_ kind: ItemKind, _ inputs: [ItemInput]) {
            guard let lane = lanes.first(where: { $0.lane == kind.lane }) else { return }
            for item in inputs {
                let x = CGFloat(item.span.start) * pps
                let width = max(4, CGFloat(item.span.duration) * pps - 2)
                let id = item.id
                let isSelected = Self.isSelected(kind, id, selection)
                items.append(Item(
                    kind: kind, id: id,
                    frame: CGRect(x: x, y: lane.y, width: width, height: lane.height),
                    label: item.label,
                    isSelected: isSelected,
                    isDimmed: selection != nil && !isSelected,
                    keyframeOffsets: item.keyframes.map { CGFloat($0 - item.span.start) * pps }
                ))
                if isSelected, kind != .music, kind != .voiceOver {
                    handles.append(Self.handle(.item(kind, id, .start), x: x - Self.itemHandleWidth, width: Self.itemHandleWidth, lane: lane))
                    handles.append(Self.handle(.item(kind, id, .end), x: x + width, width: Self.itemHandleWidth, lane: lane))
                }
            }
        }
        add(.text, input.texts)
        add(.media, input.media)
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

        var ghosts: [Ghost] = []
        if input.texts.isEmpty, input.media.isEmpty, let lane = lanes.first(where: { $0.lane == .text }) {
            ghosts.append(Ghost(lane: lane, label: String(localized: "Add text"), target: .addText))
        }
        if !input.showsCaptions || input.captions.isEmpty, let lane = lanes.first(where: { $0.lane == .captions }) {
            let label = input.captions.isEmpty ? String(localized: "Auto captions") : String(localized: "Captions off")
            ghosts.append(Ghost(lane: lane, label: label, target: .captions))
        }
        if !hasMusic, !hasVoice, let lane = lanes.first(where: { $0.lane == .audio }) {
            ghosts.append(Ghost(lane: lane, label: String(localized: "Add audio"), target: .addAudio))
        }
        self.ghosts = ghosts

        coverFrame = CGRect(x: -(Self.coverWidth + Self.coverGap), y: main.y, width: Self.coverWidth, height: main.height)
        addFrame = CGRect(x: contentWidth + Self.addGap, y: main.y + (main.height - Self.addSize) / 2, width: Self.addSize, height: Self.addSize)
    }

    private static func isSelected(_ kind: ItemKind, _ id: UUID, _ selection: EditorSelection?) -> Bool {
        switch (kind, selection) {
        case (.text, .text(let picked)?), (.media, .media(let picked)?), (.caption, .caption(let picked)?),
             (.music, .music(let picked)?), (.voiceOver, .voiceOver(let picked)?):
            picked == id
        default: false
        }
    }

    private static func handle(_ target: HandleTarget, x: CGFloat, width: CGFloat, lane: LaneFrame) -> Handle {
        let frame = CGRect(x: x, y: lane.y, width: width, height: lane.height)
        // Reached from at least `handleReach`, growing outward so the item itself stays tappable.
        let extra = max(0, handleReach - width)
        let hitX = target.edge == .start ? x - extra : x
        let hit = CGRect(x: hitX, y: lane.y - 4, width: width + extra, height: lane.height + 8)
        return Handle(target: target, frame: frame, hitFrame: hit)
    }

    // MARK: - Hit testing

    /// The handle under `point`, if any: handles come first.
    func handle(at point: CGPoint) -> Handle? {
        handles.first { $0.hitFrame.contains(point) }
    }

    /// What a tap at `point` lands on, after handles: the cover, the "+", a shortcut, a pause, a
    /// track item, a clip. Nil is empty space. `ghostFrames` are where the shortcuts were drawn.
    func hit(at point: CGPoint, ghostFrames: [CGRect] = []) -> Hit? {
        if coverFrame.contains(point) { return .cover }
        if addFrame.insetBy(dx: -6, dy: -6).contains(point) { return .addClip }
        for (ghost, frame) in zip(ghosts, ghostFrames) where frame.contains(point) {
            return ghost.target
        }
        if let pause = pauses.first(where: { $0.frame.contains(point) }) { return .pause(pause.id) }
        // The picked item first, then from the top layer down.
        if let item = items.last(where: { $0.isSelected && $0.frame.contains(point) }) { return .item(item.kind, item.id) }
        if let item = items.last(where: { $0.kind != .recording && $0.frame.contains(point) }) { return .item(item.kind, item.id) }
        if let clip = clips.first(where: { $0.frame.insetBy(dx: -1, dy: 0).contains(point) }) { return .clip(clip.id) }
        return nil
    }

    // MARK: - Snapping

    /// Edited seconds the playhead and the handles stick to: cuts between clips, the start and end
    /// of the video, of every caption and text, and keyframes.
    var snapTimes: [TimeInterval] {
        var times: [TimeInterval] = [0, input.duration]
        times += input.clips.map(\.start)
        times += input.captions.flatMap { [$0.span.start, $0.span.end] }
        times += input.texts.flatMap { [$0.span.start, $0.span.end] + $0.keyframes }
        return Array(Set(times)).sorted()
    }
}
