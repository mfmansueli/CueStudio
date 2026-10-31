//
//  SteadyValueTextTests.swift
//  Cue StudioTests
//

import SwiftUI
import Testing
@testable import Cue_Studio

/// A value that changes while a control moves keeps one width (`SteadyValueText`): "1×" and "1.1×" take the same room, so the title
/// beside the speed in Settings › Prompter, the recorder's bar and the Remote's − and + never move (a "1.1×" squeezed the title on the
/// owner's 18 Pro Max, 30/10/2026).
@MainActor
@Suite("Steady value text")
struct SteadyValueTextTests {
    private static let speeds = SpeedScale.stops.map(SpeedScale.label(forMultiple:))

    private func width(_ text: String, samples: [String]) -> CGFloat {
        let value = SteadyValueText(text: text, samples: samples).font(.body).monospacedDigit()
        return UIHostingController(rootView: value).sizeThatFits(in: CGSize(width: 1_000, height: 1_000)).width
    }

    @Test func everySpeedTakesTheSameRoom() {
        let widths = Set(Self.speeds.map { width($0, samples: Self.speeds) })
        #expect(widths.count == 1)
    }

    /// Without its samples the value is as wide as its words: the measure above is real.
    @Test func withoutSamplesTheWidthFollowsTheWords() {
        #expect(width("1×", samples: []) < width("1.1×", samples: []))
        #expect(width("1×", samples: Self.speeds) == width("1.1×", samples: []))
    }

    /// The editor's dials: "+5" takes the room of "−100", the widest end.
    @Test func aDialValueTakesTheRoomOfItsWidestEnd() {
        let samples = AdjustPanel.valueSamples
        #expect(width("+5", samples: samples) == width("-100", samples: samples))
        #expect(width("+5", samples: samples) >= width("-100", samples: []))
    }
}
