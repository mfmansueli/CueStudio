//
//  VoiceActivity.swift
//  Cue Studio
//

import Foundation

/// When someone speaks in the recordings an edit plays, from their loudness over time: what music
/// goes down under. Each recording's spans are its own seconds, so they follow the pieces wherever
/// the edit plays them.
nonisolated struct VoiceActivity: Hashable, Sendable {
    static let none = VoiceActivity()
    /// Louder than this (dBFS) counts as someone speaking.
    static let threshold: Float = -40
    /// Quieter moments shorter than this (a breath, between words) stay part of the speech.
    static let bridge: TimeInterval = 0.5
    /// Louder moments shorter than this (a knock, a click) aren't speech.
    static let shortest: TimeInterval = 0.2
    /// How often the loudness is read.
    static let interval: TimeInterval = 0.05

    /// The take's own seconds.
    var take: [TimeSpan] = []
    /// A montage's other recordings, by `ClipSource.id`.
    var sources: [UUID: [TimeSpan]] = [:]

    /// Where someone speaks in a recording read as `levels` (dBFS, one every `interval` seconds).
    static func spans(levels: [Float], interval: TimeInterval = interval) -> [TimeSpan] {
        guard interval > 0 else { return [] }
        var loud: [TimeSpan] = []
        var runStart: Int?
        for (index, level) in levels.enumerated() + [(levels.count, -Float.greatestFiniteMagnitude)] {
            if level >= threshold {
                if runStart == nil { runStart = index }
            } else if let start = runStart {
                runStart = nil
                loud.append(TimeSpan(start: Double(start) * interval, end: Double(index) * interval))
            }
        }
        // Words close together are one stretch of speech; what's left too short is a noise.
        var joined: [TimeSpan] = []
        for span in loud {
            if let last = joined.last, span.start - last.end < bridge {
                joined[joined.count - 1].end = span.end
            } else {
                joined.append(span)
            }
        }
        return joined.filter { $0.duration >= shortest }
    }

    /// Where someone speaks in a sound file.
    static func spans(inAudio url: URL) throws -> [TimeSpan] {
        spans(levels: try AudioLevelReader.levels(of: url, interval: interval))
    }

    /// Where the speech plays in `timeline` (edited seconds), joined where it touches.
    func editedSpans(in timeline: EditTimeline) -> [TimeSpan] {
        var result: [TimeSpan] = []
        var elapsed: TimeInterval = 0
        for segment in timeline.segments {
            let spoken = segment.sourceID.map { sources[$0] ?? [] } ?? take
            for span in spoken where span.overlaps(segment.span) {
                let from = max(span.start, segment.sourceStart), until = min(span.end, segment.sourceEnd)
                result.append(TimeSpan(
                    start: elapsed + (from - segment.sourceStart) / segment.speed,
                    end: elapsed + (until - segment.sourceStart) / segment.speed
                ))
            }
            elapsed += segment.duration
        }
        return TimeSpan.merged(result)
    }
}
