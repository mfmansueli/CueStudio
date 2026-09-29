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
    /// 1 plays the recording as filmed; 2 plays it twice as fast (half as long in the edit).
    var speed: Double

    init(
        id: UUID = UUID(), sourceStart: TimeInterval, sourceEnd: TimeInterval,
        transitionIn: EditTransition = .hardCut, speed: Double = 1
    ) {
        self.id = id
        self.sourceStart = sourceStart
        self.sourceEnd = sourceEnd
        self.transitionIn = transitionIn
        self.speed = Self.clampedSpeed(speed)
    }

    init(id: UUID = UUID(), span: TimeSpan, transitionIn: EditTransition = .hardCut, speed: Double = 1) {
        self.init(id: id, sourceStart: span.start, sourceEnd: span.end, transitionIn: transitionIn, speed: speed)
    }

    /// How long the piece plays in the edit (its stretch of the recording over its speed).
    var duration: TimeInterval { sourceLength / speed }

    /// How much of the recording the piece takes, whatever its speed.
    var sourceLength: TimeInterval { max(0, sourceEnd - sourceStart) }

    var span: TimeSpan { TimeSpan(start: sourceStart, end: sourceEnd) }

    static func clampedSpeed(_ speed: Double) -> Double {
        guard speed.isFinite, speed > 0 else { return 1 }
        return min(max(speed, speedRange.lowerBound), speedRange.upperBound)
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, sourceStart, sourceEnd, transitionIn, speed
    }

    /// Pieces saved before transitions or speed existed are hard cuts at 1×, and so is a
    /// transition this version doesn't know.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceStart = try container.decode(TimeInterval.self, forKey: .sourceStart)
        sourceEnd = try container.decode(TimeInterval.self, forKey: .sourceEnd)
        transitionIn = (try? container.decodeIfPresent(EditTransition.self, forKey: .transitionIn)) ?? .hardCut
        speed = Self.clampedSpeed((try? container.decodeIfPresent(Double.self, forKey: .speed)) ?? 1)
    }
}
