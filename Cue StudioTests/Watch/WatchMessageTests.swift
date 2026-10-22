//
//  WatchMessageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Commands and states cross WatchConnectivity as they left.
@Suite("Apple Watch messages")
struct WatchMessageTests {
    @Test(arguments: [
        WatchAction.refresh, .record, .cancelCountdown, .stop, .rehearse, .endRehearsal, .togglePlay, .backward, .faster, .slower,
        .setSpeed(multiple: 1.4), .done,
    ])
    func everyCommandArrivesAsSent(_ action: WatchAction) {
        let command = WatchCommand(action: action)
        #expect(WatchMessage.command(in: WatchMessage.encode(command)) == command)
    }

    @Test func aStateArrivesAsSent() {
        let state = WatchPhoneState(
            phase: .saved(take: 4, seconds: 52.5), scriptTitle: "Lançamento de outono", followsVoice: true, speedMultiple: 1.2,
            isPlaying: true, recordingStartedAt: Date(timeIntervalSince1970: 100), answering: UUID(), sentAt: Date(timeIntervalSince1970: 200)
        )
        #expect(WatchMessage.state(in: WatchMessage.encode(state)) == state)
    }

    @Test func somethingElseIsNoMessage() {
        #expect(WatchMessage.command(in: ["command": Data("{}".utf8)]) == nil)
        #expect(WatchMessage.state(in: [:]) == nil)
    }
}
