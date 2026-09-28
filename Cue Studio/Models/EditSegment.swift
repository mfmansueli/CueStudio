//
//  EditSegment.swift
//  Cue Studio
//

import Foundation

/// One piece of the edited video: a stretch of the original recording that plays.
nonisolated struct EditSegment: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    /// Seconds of the original recording.
    var sourceStart: TimeInterval
    var sourceEnd: TimeInterval
    /// How this piece takes over from the one before it; a hard cut by default. The first piece
    /// has nothing before it, so its transition is always `hardCut` (see `EditTimeline`).
    var transitionIn: EditTransition

    init(id: UUID = UUID(), sourceStart: TimeInterval, sourceEnd: TimeInterval, transitionIn: EditTransition = .hardCut) {
        self.id = id
        self.sourceStart = sourceStart
        self.sourceEnd = sourceEnd
        self.transitionIn = transitionIn
    }

    init(id: UUID = UUID(), span: TimeSpan, transitionIn: EditTransition = .hardCut) {
        self.init(id: id, sourceStart: span.start, sourceEnd: span.end, transitionIn: transitionIn)
    }

    var duration: TimeInterval { max(0, sourceEnd - sourceStart) }

    var span: TimeSpan { TimeSpan(start: sourceStart, end: sourceEnd) }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case id, sourceStart, sourceEnd, transitionIn
    }

    /// Pieces saved before transitions existed are hard cuts, and so is a transition this version
    /// doesn't know.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceStart = try container.decode(TimeInterval.self, forKey: .sourceStart)
        sourceEnd = try container.decode(TimeInterval.self, forKey: .sourceEnd)
        transitionIn = (try? container.decodeIfPresent(EditTransition.self, forKey: .transitionIn)) ?? .hardCut
    }
}
