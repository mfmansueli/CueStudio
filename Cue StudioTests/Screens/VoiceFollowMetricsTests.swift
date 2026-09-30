//
//  VoiceFollowMetricsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("VoiceFollowMetrics")
struct VoiceFollowMetricsTests {
    @Test func startupAndFirstWordsCountFromTurningItOn() {
        var metrics = VoiceFollowMetrics()
        metrics.enabled(at: 10)
        metrics.listening(at: 10.4)
        metrics.transcript(" ", receivedAt: 10.6, alignedAt: 10.6)
        metrics.transcript(" hello", receivedAt: 11.2, alignedAt: 11.201)
        #expect(abs((metrics.startup ?? 0) - 0.4) < 0.0001)
        #expect(abs((metrics.firstWords ?? 0) - 1.2) < 0.0001)
        #expect(metrics.alignment.count == 2)
    }

    @Test func onsetTimesAreMeasuredOncePerOnset() {
        var metrics = VoiceFollowMetrics()
        metrics.voice(true, heardAt: 1, shownAt: 1.002)
        metrics.moved(at: 1.3)
        metrics.moved(at: 1.5)
        #expect(metrics.onsetToIndicator.count == 1)
        #expect(abs(metrics.onsetToIndicator[0] - 0.002) < 0.0001)
        #expect(metrics.onsetToMovement.count == 1)
        #expect(abs(metrics.onsetToMovement[0] - 0.3) < 0.0001)
    }

    /// "Speaking" with nothing recognized in it was the room, not a voice.
    @Test func speakingWithoutWordsIsAFalseStart() {
        var metrics = VoiceFollowMetrics()
        metrics.voice(true, heardAt: 1, shownAt: 1)
        metrics.voice(false, heardAt: 2, shownAt: 2)
        metrics.voice(true, heardAt: 3, shownAt: 3)
        metrics.transcript(" hello", receivedAt: 3.5, alignedAt: 3.5)
        metrics.voice(false, heardAt: 4, shownAt: 4)
        #expect(metrics.onsets == 2)
        #expect(metrics.falseOnsets == 1)
    }

    @Test func percentiles() {
        let values = (1...100).map(Double.init)
        #expect(VoiceFollowMetrics.percentile(values, 0.5) == 51)
        #expect(VoiceFollowMetrics.percentile(values, 0.95) == 95)
        #expect(VoiceFollowMetrics.percentile([], 0.5) == nil)
    }

    @Test func turningItOnAgainStartsOver() {
        var metrics = VoiceFollowMetrics()
        metrics.enabled(at: 0)
        metrics.downloading()
        metrics.confirmed(ahead: 1.5)
        metrics.enabled(at: 5)
        #expect(!metrics.downloaded)
        #expect(metrics.overshoot.isEmpty)
        #expect(metrics.summary.contains("startup"))
    }
}
