//
//  WatchScreenRuleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The watch's screen (v31 board, every state): only what the iPhone said, a command waiting until the iPhone shows its
/// effect, and an old state never shown as current.
@Suite("Apple Watch screen rule")
struct WatchScreenRuleTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func screen(
        _ phase: WatchPhase?, reachable: Bool = true, pending: WatchAction? = nil, waited: TimeInterval = 1, answered: Bool = false,
        leftSaved: Bool = false
    ) -> WatchScreen {
        let command = pending.map { WatchCommand(action: $0) }
        var state = phase.map { WatchPhoneState(phase: $0) }
        if answered { state?.answering = command?.id }
        return WatchScreenRule.screen(
            state: state, isReachable: reachable, pending: command, pendingSince: now.addingTimeInterval(-waited), now: now,
            leftSavedTake: leftSaved
        )
    }

    @Test func nothingHeardYetIsCheckingAndNeverAnOldState() {
        #expect(screen(nil) == .checking)
        #expect(screen(nil, reachable: false) == .checking)
        #expect(screen(.recording, reachable: false) == .lost, "the last state shows only as old, under No connection")
    }

    @Test func eachPhaseOfTheIPhoneIsItsScreen() {
        #expect(screen(.noSession) == .noSession)
        #expect(screen(.unavailable) == .unavailable)
        #expect(screen(.ready) == .ready)
        #expect(screen(.countdown(remaining: 2)) == .countdown(remaining: 2))
        #expect(screen(.recording) == .recording)
        #expect(screen(.saving) == .saving)
        #expect(screen(.saved(take: 4, seconds: 52)) == .saved(take: 4, seconds: 52))
        #expect(screen(.rehearsal) == .rehearsal)
        #expect(screen(.failedStart) == .failedStart)
        #expect(screen(.failedSave) == .failedSave)
    }

    @Test func recordWaitsForTheIPhoneAndNeverSaysRecordingBeforeIt() {
        #expect(screen(.ready, pending: .record) == .requesting)
        #expect(screen(.saved(take: 1, seconds: 3), pending: .record) == .requesting)
        // The iPhone shows the countdown: the wait is over even before it names the command.
        #expect(screen(.countdown(remaining: 3), pending: .record) == .countdown(remaining: 3))
        // Named as answered with no take: why not.
        #expect(screen(.failedStart, pending: .record, answered: true) == .failedStart)
    }

    @Test func endWaitsThenShowsTheSaving() {
        #expect(screen(.recording, pending: .stop) == .stopping)
        #expect(screen(.saving, pending: .stop) == .saving)
        #expect(screen(.saved(take: 2, seconds: 10), pending: .stop, answered: true) == .saved(take: 2, seconds: 10))
    }

    @Test func aWaitWithNoAnswerInTimeIsNoResponse() {
        #expect(screen(.ready, pending: .record, waited: WatchScreenRule.answerTimeout + 1) == .noResponse)
        #expect(screen(.recording, pending: .stop, waited: WatchScreenRule.answerTimeout + 1) == .noResponse)
        // A command whose effect shows needs no answer in time: a long save is still Saving.
        #expect(screen(.saving, pending: .stop, waited: 30) == .saving)
        #expect(screen(.rehearsal, pending: .togglePlay, waited: 30) == .rehearsal)
    }

    @Test func doneLeavesTheSavedTakeOnTheWatchOnly() {
        #expect(screen(.saved(take: 3, seconds: 5), leftSaved: true) == .ready)
    }

    @Test func aTakesTimeReadsAsMinutesAndSeconds() {
        #expect(WatchScreenRule.clock(0) == "00:00")
        #expect(WatchScreenRule.clock(42.9) == "00:42")
        #expect(WatchScreenRule.clock(752) == "12:32")
        #expect(WatchScreenRule.clock(-3) == "00:00")
    }
}
