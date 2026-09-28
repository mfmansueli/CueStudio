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

    init(id: UUID = UUID(), sourceStart: TimeInterval, sourceEnd: TimeInterval) {
        self.id = id
        self.sourceStart = sourceStart
        self.sourceEnd = sourceEnd
    }

    init(id: UUID = UUID(), span: TimeSpan) {
        self.init(id: id, sourceStart: span.start, sourceEnd: span.end)
    }

    var duration: TimeInterval { max(0, sourceEnd - sourceStart) }

    var span: TimeSpan { TimeSpan(start: sourceStart, end: sourceEnd) }
}
