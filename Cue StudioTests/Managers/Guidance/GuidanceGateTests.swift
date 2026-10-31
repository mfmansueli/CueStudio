//
//  GuidanceGateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The one gatekeeper of what Cue suggests on its own: one suggestion a place, nothing in place of one the creator closed, the creator's
/// queue first, the Ultra AI line stepping aside, celebrations ending the moment for the sheets that ask, and sessions.
@MainActor
@Suite("GuidanceGate")
struct GuidanceGateTests {
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    @Test func oneSuggestionAPlaceAndWhatIsUpKeepsIt() {
        let gate = GuidanceGate()
        #expect(gate.mayShow(.voiceTip, at: .scripts))
        gate.shown(.voiceTip, at: .scripts)
        gate.setWaiting(.voyageTip, at: .scripts, true)
        #expect(!gate.mayShow(.voyageTip, at: .scripts), "the voice tip is up: the voyage's waits, nothing flickers")
        #expect(gate.mayShow(.voiceTip, at: .scripts))
        #expect(gate.mayShow(.voyageTip, at: .takes), "Takes is another place")
        gate.left(.voiceTip, at: .scripts)
        #expect(gate.mayShow(.voyageTip, at: .scripts))
    }

    @Test func aDueVoyageTipHoldsBackWhatComesAfterIt() {
        let gate = GuidanceGate()
        gate.setWaiting(.voyageTip, at: .scripts, true)
        #expect(!gate.mayShow(.voiceTip, at: .scripts))
        #expect(!gate.mayShow(.ultraInvite, at: .scripts))
        gate.setWaiting(.voyageTip, at: .scripts, false)
        #expect(gate.mayShow(.ultraInvite, at: .scripts))
    }

    @Test func theUltraLineStepsAsideForATipButATipNeverForIt() {
        let gate = GuidanceGate()
        gate.shown(.ultraInvite, at: .scripts)
        #expect(gate.mayShow(.voiceTip, at: .scripts), "a tip may take the line's place")
        gate.setWaiting(.voyageTip, at: .scripts, true)
        #expect(!gate.mayShow(.ultraInvite, at: .scripts), "the line folds when the voyage has something to say")
        #expect(gate.mayShow(.voyageTip, at: .scripts))
        gate.left(.ultraInvite, at: .scripts)
        gate.setWaiting(.voyageTip, at: .scripts, false)
        gate.shown(.voiceTip, at: .scripts)
        #expect(!gate.mayShow(.ultraInvite, at: .scripts))
    }

    @Test func theCreatorsQueueGoesFirstAndTipsStepAsideForIt() {
        let gate = GuidanceGate()
        gate.shown(.voiceTip, at: .takes)
        gate.shown(.continuePosting, at: .takes)
        #expect(!gate.mayShow(.voiceTip, at: .takes))
        #expect(!gate.mayShow(.voyageTip, at: .takes))
        gate.left(.continuePosting, at: .takes)
        #expect(gate.mayShow(.voyageTip, at: .takes))
    }

    @Test func afterAClosedSuggestionNothingTakesItsPlaceThisSession() {
        let clock = Clock()
        let gate = GuidanceGate(now: { clock.now })
        gate.shown(.voyageTip, at: .scripts)
        gate.left(.voyageTip, at: .scripts, closed: true)
        #expect(!gate.mayShow(.voiceTip, at: .scripts), "no voice tip 1.2 s after the voyage's ✕ (C1)")
        #expect(!gate.mayShow(.ultraInvite, at: .scripts))
        #expect(gate.mayShow(.continuePosting, at: .scripts), "the creator's own work is never put away by a ✕")
        #expect(gate.mayShow(.voiceTip, at: .takes))
        gate.reopenPlaces()
        #expect(gate.mayShow(.voiceTip, at: .scripts), "the guide switched back on in Settings")
        gate.left(.voyageTip, at: .scripts, closed: true)
        gate.appLeftScreen()
        clock.now += 10 * 60
        gate.appBecameActive()
        #expect(!gate.mayShow(.voiceTip, at: .scripts), "ten minutes away is the same session")
        gate.appLeftScreen()
        clock.now += GuidanceGate.sessionGap
        gate.appBecameActive()
        #expect(gate.mayShow(.voiceTip, at: .scripts), "a new session")
    }

    @Test func theSheetsThatAskNeverFollowACelebrationOrTheFirstRecordingsSession() {
        let clock = Clock()
        let gate = GuidanceGate(now: { clock.now })
        #expect(!gate.mayAsk(firstTakeAt: clock.now + 60), "the first take was recorded in this session")
        #expect(gate.mayAsk(firstTakeAt: clock.now - 3600), "a take from an earlier session")
        #expect(gate.mayAsk(firstTakeAt: nil))
        gate.celebrated()
        #expect(!gate.mayAsk(firstTakeAt: clock.now - 3600), "never right after a celebration")
        #expect(!gate.mayAsk(firstTakeAt: nil))
        gate.appLeftScreen()
        clock.now += GuidanceGate.sessionGap + 1
        gate.appBecameActive()
        #expect(gate.mayAsk(firstTakeAt: clock.now - 3600), "the next session may ask")
    }
}
