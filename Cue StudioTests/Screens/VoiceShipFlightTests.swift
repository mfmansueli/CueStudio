//
//  VoiceShipFlightTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// My Cue Voice's spaceship leaving the full tank (`VoiceShipFlight`): it never jumps between two frames at 120 Hz, it turns its nose to the
/// screen as its top view becomes the front one, it grows as something approaching does (slowly, then fast) and it leaves by the top right,
/// with the haptic's bright tap as it passes the glass.
@Suite("My Cue Voice · the ship's flight")
struct VoiceShipFlightTests {
    private let origin = CGPoint(x: 260, y: 391)
    private let anchor = CGPoint(x: 201, y: 316)
    private let frame = 1.0 / 120

    private func poses() -> [(time: Double, pose: VoiceShipFlight.Pose)] {
        stride(from: 0, to: VoiceShipFlight.duration, by: frame).compactMap { time in
            VoiceShipFlight.pose(at: time, origin: origin, anchor: anchor).map { (time, $0) }
        }
    }

    @Test func itStartsWhereTheRunLeftItAndIsGoneAfterItsDuration() throws {
        let first = try #require(VoiceShipFlight.pose(at: 0, origin: origin, anchor: anchor))
        #expect(first.position == origin)
        #expect(first.view == .top)
        #expect(VoiceShipFlight.pose(at: VoiceShipFlight.duration, origin: origin, anchor: anchor) == nil)
    }

    @Test func itNeverJumpsBetweenTwoFramesBeforeItRushesAtTheGlass() {
        let all = poses()
        for (previous, next) in zip(all, all.dropFirst()) where next.pose.scale < 4 {
            let step = hypot(next.pose.position.x - previous.pose.position.x, next.pose.position.y - previous.pose.position.y)
            #expect(step < 9, "A jump of \(step) pt at \(next.time) s")
        }
    }

    @Test func itBanksIntoTheTurnAndReachesItStillMoving() {
        let top = poses().filter { $0.pose.view == .top && $0.time > VoiceShipFlight.anticipation }
        #expect(top.contains { abs($0.pose.bank) > 0.5 }, "It banks into the curve")
        #expect(VoiceShipFlight.launchTiming(1) == 1)
        let last = VoiceShipFlight.launchTiming(1) - VoiceShipFlight.launchTiming(0.98)
        #expect(last / 0.02 > 0.5, "Still moving as it turns to the viewer")
    }

    @Test func theTopViewFlattensBeforeTheFrontViewOpens() {
        let all = poses()
        let lastTop = all.last { $0.pose.view == .top }
        let firstFront = all.first { $0.pose.view == .front }
        #expect((lastTop?.pose.along ?? 1) < 0.15, "The nose points at the screen before the view changes")
        #expect((firstFront?.pose.opening ?? 1) < 0.15, "The front view opens from a sliver")
    }

    @Test func itGrowsSlowlyThenFastAndLeavesByTheTopRight() throws {
        let front = poses().filter { $0.pose.view == .front }
        let scales = front.map(\.pose.scale)
        #expect(zip(scales, scales.dropFirst()).allSatisfy { $0 < $1 }, "It keeps coming closer")
        let middle = scales[scales.count / 2]
        let last = try #require(scales.last)
        #expect(middle < 2.5 && last > 7, "Slowly, then all at once: \(middle) halfway, \(last) at the end")
        let end = try #require(front.last).pose.position
        #expect(end.x > anchor.x + 150 && end.y < anchor.y - 150, "It passes the glass off the top right")
    }

    @MainActor
    @Test func theHapticsBrightTapFallsAsItPassesTheGlass() throws {
        let brightest = try #require(poses().max { $0.pose.flash < $1.pose.flash })
        let tap = try #require(HapticPatterns.voiceFuel.last)
        #expect(abs(VoiceFuelPainter.runSeconds + brightest.time - tap.time) < 0.03)
        let click = HapticPatterns.voiceFuel.first { abs($0.time - VoiceFuelPainter.runSeconds) < 0.01 }
        #expect(click != nil, "The tank locks full as the run ends")
        let boost = VoiceFuelPainter.runSeconds + VoiceShipFlight.anticipation + VoiceShipFlight.launch
        let knock = HapticPatterns.voiceFuel.first { $0.duration == nil && abs($0.time - boost) < 0.01 }
        #expect((knock?.intensity ?? 0) > 0.7, "A hard knock with the shock wave as it boosts at the screen")
    }
}
