//
//  TimeSpan.swift
//  Cue Studio
//

import Foundation

/// A stretch of the original recording, in seconds.
nonisolated struct TimeSpan: Codable, Hashable, Sendable {
    var start: TimeInterval
    var end: TimeInterval

    var duration: TimeInterval { max(0, end - start) }

    func contains(_ time: TimeInterval) -> Bool { time >= start && time < end }

    /// Whether the two share any time (touching ends don't count).
    func overlaps(_ other: TimeSpan) -> Bool { other.end > start && other.start < end }

    /// What is left of this span once `holes` are taken out, in order.
    func subtracting(_ holes: [TimeSpan]) -> [TimeSpan] {
        var pieces = [self]
        for hole in holes.sorted(by: { $0.start < $1.start }) {
            pieces = pieces.flatMap { piece -> [TimeSpan] in
                guard hole.overlaps(piece) else { return [piece] }
                var result: [TimeSpan] = []
                if hole.start > piece.start { result.append(TimeSpan(start: piece.start, end: hole.start)) }
                if hole.end < piece.end { result.append(TimeSpan(start: hole.end, end: piece.end)) }
                return result
            }
        }
        return pieces
    }

    /// `spans` sorted, with the ones that overlap or touch joined.
    static func merged(_ spans: [TimeSpan]) -> [TimeSpan] {
        var result: [TimeSpan] = []
        for span in spans.sorted(by: { $0.start < $1.start }) {
            if let last = result.last, span.start <= last.end + 0.001 {
                result[result.count - 1].end = max(last.end, span.end)
            } else {
                result.append(span)
            }
        }
        return result
    }
}
