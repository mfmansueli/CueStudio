//
//  VoiceActivityTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// When someone speaks, from loudness readings: words close together are one stretch, a click is
/// not speech, and the stretches follow the pieces wherever the edit plays them.
@Suite("Voice activity")
struct VoiceActivityTests {
    /// Readings every 0.05 s: loud (−20 dBFS) inside `loud`, quiet (−60) elsewhere.
    private func levels(seconds: Double, loud: [ClosedRange<Double>]) -> [Float] {
        (0..<Int(seconds / 0.05)).map { index in
            let time = Double(index) * 0.05
            return loud.contains { $0.contains(time) } ? -20 : -60
        }
    }

    @Test func wordsCloseTogetherAreOneStretchOfSpeech() {
        let spans = VoiceActivity.spans(levels: levels(seconds: 6, loud: [1...1.8, 2.0...2.6, 4...5]))
        #expect(spans.count == 2)
        #expect(abs(spans[0].start - 1) < 0.06)
        #expect(abs(spans[0].end - 2.65) < 0.06)
        #expect(abs(spans[1].start - 4) < 0.06)
    }

    @Test func aClickIsNotSpeech() {
        let spans = VoiceActivity.spans(levels: levels(seconds: 3, loud: [1...1.05]))
        #expect(spans.isEmpty)
    }

    @Test func speechFollowsThePiecesAtTheirSpeed() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.trimStart(to: 2)
        timeline.split(atEdited: 4)
        timeline.setSpeed(2, forSegmentAt: 1)
        var activity = VoiceActivity()
        activity.take = [TimeSpan(start: 3, end: 5), TimeSpan(start: 8, end: 9)]
        let spans = activity.editedSpans(in: timeline)
        // 3–5 s: 1–3 s in the edit (the second piece starts at 6 s of the take, 4 s in).
        // 8–9 s: in the doubled piece, 4 + (8 − 6) / 2 = 5 to 5.5 s.
        #expect(spans.count == 2)
        #expect(abs(spans[0].start - 1) < 0.001 && abs(spans[0].end - 3) < 0.001)
        #expect(abs(spans[1].start - 5) < 0.001 && abs(spans[1].end - 5.5) < 0.001)
    }

    @Test func anotherRecordingSpeaksWhereItPlays() {
        let other = UUID()
        var timeline = EditTimeline(sourceDuration: 4)
        timeline.insertClip(source: other, duration: 3)
        var activity = VoiceActivity()
        activity.sources[other] = [TimeSpan(start: 1, end: 2)]
        #expect(activity.editedSpans(in: timeline) == [TimeSpan(start: 5, end: 6)])
    }
}
