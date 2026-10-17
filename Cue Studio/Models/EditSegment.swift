//
//  EditSegment.swift
//  Cue Studio
//

import Foundation

/// One piece of the edited video: a stretch of the original recording that plays, at its speed.
nonisolated struct EditSegment: Codable, Hashable, Identifiable, Sendable {
    /// Slowest and fastest a piece can play (the Speed tool offers 0.5× to 2×).
    static let speedRange: ClosedRange<Double> = 0.25...4

    var id: UUID
    /// Seconds of the original recording.
    var sourceStart: TimeInterval
    var sourceEnd: TimeInterval
    /// How this piece takes over from the one before it; a hard cut by default. The first piece
    /// has nothing before it, so its transition is always `hardCut` (see `EditTimeline`).
    var transitionIn: EditTransition
    /// How long that transition lasts; nil for its own length (`EditTransition.duration`).
    var transitionDuration: TimeInterval?
    /// 1 plays the recording as filmed; 2 plays it twice as fast (half as long in the edit).
    var speed: Double
    /// Speed › Curve: the clip speeds up and slows down as it plays (`speed` is kept for when the curve goes); nil plays it
    /// at `speed` all along.
    var speedCurve: SpeedCurve?
    /// The recording it comes from: nil for the take being edited, else another take or video in
    /// the montage (`TakeEdit.sources`). `sourceStart` and `sourceEnd` are seconds of that one.
    var sourceID: UUID?
    /// A slow zoom over the piece; nil plays it as filmed.
    var zoom: SectionZoom?
    /// How strong the zoom is, 0 to 1 (1 is 1.3× at most); 0.5 for new clips.
    var zoomAmount: Double = 0.5
    /// The clip's own sound, 0 to 2 (200%), on top of the Voice tool's volume.
    var volume: Double = 1
    /// "Mute this clip".
    var isMuted = false
    /// "Keep voice pitch": a faster or slower clip keeps the voice's tone; off, it rises or falls
    /// with the speed.
    var keepsPitch = true
    /// What this clip changes of the take's look (Adjust, Filters, Background); nil plays it with
    /// the take's own. Cutting or duplicating the clip copies it to the pieces.
    var look: ClipLook?
    /// Stabilize: how strongly the camera's shake is smoothed out of this clip (`StabilizationPath`); nil plays it as filmed.
    var stabilization: StabilizationLevel?

    static let volumeRange: ClosedRange<Double> = 0...2

    init(
        id: UUID = UUID(), sourceStart: TimeInterval, sourceEnd: TimeInterval,
        transitionIn: EditTransition = .hardCut, speed: Double = 1, sourceID: UUID? = nil, zoom: SectionZoom? = nil
    ) {
        self.id = id
        self.zoom = zoom
        self.sourceStart = sourceStart
        self.sourceEnd = sourceEnd
        self.transitionIn = transitionIn
        self.speed = Self.clampedSpeed(speed)
        self.sourceID = sourceID
    }

    init(
        id: UUID = UUID(), span: TimeSpan, transitionIn: EditTransition = .hardCut, speed: Double = 1, sourceID: UUID? = nil,
        zoom: SectionZoom? = nil
    ) {
        self.init(id: id, sourceStart: span.start, sourceEnd: span.end, transitionIn: transitionIn, speed: speed, sourceID: sourceID, zoom: zoom)
    }

    /// The same clip (speed, zoom, sound, look) over another stretch of its recording, as a new piece
    /// unless `id` says otherwise.
    func piece(_ span: TimeSpan, id: UUID = UUID(), transitionIn: EditTransition = .hardCut) -> EditSegment {
        var piece = self
        piece.id = id
        piece.sourceStart = span.start
        piece.sourceEnd = span.end
        piece.transitionIn = transitionIn
        // A part of a curved clip keeps its part of the curve, so it plays exactly as it did.
        if let curve = speedCurve, sourceLength > 0 {
            piece.speedCurve = curve.part(from: (span.start - sourceStart) / sourceLength, to: (span.end - sourceStart) / sourceLength)
        }
        return piece
    }

    /// How long the piece plays in the edit (its stretch of the recording at its speed, or along its curve).
    var duration: TimeInterval {
        speedCurve.map { $0.editedLength(sourceLength: sourceLength) } ?? sourceLength / speed
    }

    /// Seconds into the piece in the edit where `offset` seconds into its stretch of the recording play.
    func editedOffset(forSource offset: TimeInterval) -> TimeInterval {
        speedCurve.map { $0.editedOffset(forSource: offset, sourceLength: sourceLength) } ?? offset / speed
    }

    /// Seconds into its stretch of the recording shown `offset` seconds into the piece in the edit.
    func sourceOffset(forEdited offset: TimeInterval) -> TimeInterval {
        speedCurve.map { $0.sourceOffset(forEdited: offset, sourceLength: sourceLength) } ?? offset * speed
    }

    /// Like `editedOffset(forSource:)`, going on past the piece's ends at the speed of that end (something pinned to the
    /// recording can run past its piece).
    func extendedEditedOffset(forSource offset: TimeInterval) -> TimeInterval {
        if offset < 0 { return offset / edgeSpeed(atStart: true) }
        if offset > sourceLength { return duration + (offset - sourceLength) / edgeSpeed(atStart: false) }
        return editedOffset(forSource: offset)
    }

    /// Like `sourceOffset(forEdited:)`, going on past the piece's ends at the speed of that end.
    func extendedSourceOffset(forEdited offset: TimeInterval) -> TimeInterval {
        if offset < 0 { return offset * edgeSpeed(atStart: true) }
        if offset > duration { return sourceLength + (offset - duration) * edgeSpeed(atStart: false) }
        return sourceOffset(forEdited: offset)
    }

    /// The speed at the piece's start (`atStart`) or end: what the other side of a transition plays at.
    func edgeSpeed(atStart: Bool) -> Double {
        speedCurve.map { $0.speed(at: atStart ? 0 : 1) } ?? speed
    }

    /// Whether it plays at another speed than filmed (a speed or a curve).
    var changesSpeed: Bool { speedCurve != nil || abs(speed - 1) > 0.000_1 }

    /// Whether it plays at the same pace as `other` all along (the same speed, no curve on either).
    func playsAtSamePace(as other: EditSegment) -> Bool {
        speedCurve == nil && other.speedCurve == nil && speed == other.speed
    }

    /// How much of the recording the piece takes, whatever its speed.
    var sourceLength: TimeInterval { max(0, sourceEnd - sourceStart) }

    var span: TimeSpan { TimeSpan(start: sourceStart, end: sourceEnd) }

    static func clampedSpeed(_ speed: Double) -> Double {
        guard speed.isFinite, speed > 0 else { return 1 }
        return min(max(speed, speedRange.lowerBound), speedRange.upperBound)
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, sourceStart, sourceEnd, transitionIn, transitionDuration, speed, sourceID, zoom, zoomAmount, volume, isMuted, keepsPitch, look
        case stabilization, speedCurve
    }

    /// Pieces saved before transitions or speed existed are hard cuts at 1×, and so is a
    /// transition this version doesn't know. Pieces saved before montages are of the take itself.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceStart = try container.decode(TimeInterval.self, forKey: .sourceStart)
        sourceEnd = try container.decode(TimeInterval.self, forKey: .sourceEnd)
        transitionIn = (try? container.decodeIfPresent(EditTransition.self, forKey: .transitionIn)) ?? .hardCut
        transitionDuration = try? container.decodeIfPresent(TimeInterval.self, forKey: .transitionDuration)
        speed = Self.clampedSpeed((try? container.decodeIfPresent(Double.self, forKey: .speed)) ?? 1)
        sourceID = try? container.decodeIfPresent(UUID.self, forKey: .sourceID)
        zoom = try? container.decodeIfPresent(SectionZoom.self, forKey: .zoom)
        // Clips saved before the strength had a fixed zoom: 1.12× for push and pull, 1.15× punched in.
        zoomAmount = (try? container.decodeIfPresent(Double.self, forKey: .zoomAmount)) ?? (zoom == .punchIn ? 0.5 : 0.4)
        volume = min(max((try? container.decodeIfPresent(Double.self, forKey: .volume)) ?? 1, Self.volumeRange.lowerBound), Self.volumeRange.upperBound)
        isMuted = (try? container.decodeIfPresent(Bool.self, forKey: .isMuted)) ?? false
        keepsPitch = (try? container.decodeIfPresent(Bool.self, forKey: .keepsPitch)) ?? true
        // Clips saved before clips could look different play with the take's look.
        look = (try? container.decodeIfPresent(ClipLook.self, forKey: .look))?.normalized
        // Clips saved before Stabilize play as filmed.
        stabilization = try? container.decodeIfPresent(StabilizationLevel.self, forKey: .stabilization)
        // Clips saved before curves play at their speed.
        speedCurve = try? container.decodeIfPresent(SpeedCurve.self, forKey: .speedCurve)
    }
}
