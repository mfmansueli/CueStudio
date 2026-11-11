//
//  RecordingBarLayoutTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
import UIKit
@testable import Cue_Studio

/// The recording bar's two items share the bar's room: the REC pill keeps its size and the take's name gets what is left.
@MainActor
@Suite("RecordingBarLayout")
struct RecordingBarLayoutTests {
    private func width(of view: some View) -> CGFloat {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: CGFloat.infinity, height: .infinity)).width
    }

    @Test func aLongNameShrinksIntoTheRoomBesideTheClock() {
        let bar = RecordingBarLayout(maxWidth: 240) {
            Color.red.frame(width: 120, height: 40)
            Text("Obiettivo di durata raggiunto · 1:00 · Ripresa 12").lineLimit(1).minimumScaleFactor(0.75)
        }
        #expect(width(of: bar) <= 240)
    }

    @Test func aShortNameKeepsItsOwnWidth() {
        let name = Text("Take 2").lineLimit(1)
        let bar = RecordingBarLayout(maxWidth: 400) {
            Color.red.frame(width: 120, height: 40)
            name
        }
        #expect(abs(width(of: bar) - (120 + 8 + width(of: name))) < 0.5)
    }

    @Test func theClockNeverShrinks() {
        let bar = RecordingBarLayout(maxWidth: 100) {
            Color.red.frame(width: 120, height: 40)
            Text("Take 2")
        }
        #expect(width(of: bar) >= 120)
    }
}
