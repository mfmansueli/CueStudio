//
//  RecordingBarStateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The compact recording bar and the whole one that a tap brings back for a few seconds. The
/// counting is tested with instants passed in, so nothing here depends on how busy the machine is.
@MainActor
@Suite("RecordingBarState")
struct RecordingBarStateTests {
    private func makeState(milliseconds: Int = 40) -> RecordingBarState {
        let state = RecordingBarState()
        state.expandedDuration = .milliseconds(milliseconds)
        return state
    }

    /// Polls until `condition` holds (or a few seconds pass), instead of sleeping a fixed time.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func itStartsCompactAndStaysOpenFourSeconds() {
        #expect(!RecordingBarState().isExpanded)
        #expect(RecordingBarState().expandedDuration == .seconds(4))
    }

    @Test func aTapOpensTheWholeBarAndItClosesByItself() async {
        let state = makeState()
        state.expand()
        #expect(state.isExpanded)
        await waitUntil { !state.isExpanded }
        #expect(!state.isExpanded)
    }

    @Test func collapsingNowClosesItAndCancelsTheCount() async {
        let state = makeState(milliseconds: 30)
        state.expand()
        state.collapse()
        #expect(!state.isExpanded)
        // The count that was running is cancelled: opening it again is not closed by the old one.
        state.expandedDuration = .seconds(30)
        state.expand()
        try? await Task.sleep(for: .milliseconds(120))
        #expect(state.isExpanded)
        state.collapse()
        #expect(!state.isExpanded)
    }

    @Test func tappingAgainStartsTheCountFromTheNewTap() {
        let state = RecordingBarState()
        let start = ContinuousClock.now
        state.expand(at: start)
        state.expand(at: start + .seconds(2))
        #expect(state.lastArmed == start + .seconds(2))
        state.collapse()
    }

    @Test func touchingAControlOfAClosedBarDoesNothing() {
        let state = RecordingBarState()
        let before = state.lastArmed
        state.touch(at: before + .seconds(10))
        #expect(!state.isExpanded)
        #expect(state.lastArmed == before)
    }

    @Test func aTouchRightAfterATapDoesNotRestartTheCount() {
        let state = RecordingBarState()
        let start = ContinuousClock.now
        state.expand(at: start)
        // A slider's drag passes through many points: none of the first half second re-arms it.
        for milliseconds in stride(from: 16, through: 480, by: 16) {
            state.touch(at: start + .milliseconds(milliseconds))
        }
        #expect(state.lastArmed == start)
        state.collapse()
    }

    @Test func aTouchLaterOnKeepsTheOpenBarOpenLonger() {
        let state = RecordingBarState()
        let start = ContinuousClock.now
        state.expand(at: start)
        let later = start + RecordingBarState.rearmThreshold + .milliseconds(100)
        state.touch(at: later)
        #expect(state.lastArmed == later)
        #expect(state.isExpanded)
        state.collapse()
    }
}
