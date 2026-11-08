//
//  PersonMaskTrackTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The person mask steadied in play order (`PersonMaskTrack`), on made-up masks: a shimmering edge settles, a move is followed at
/// once, a failed frame keeps the last outline for half a second and then fades, a seek or a cut starts again, and the same frames
/// in the same order always give the same masks (the preview and the export).
@Suite("Person mask track")
struct PersonMaskTrackTests {
    private static let width = 20, height = 10
    private static let frame = 1.0 / 30

    /// The person filling columns `from..<to`, `edge` on the column after them.
    private func mask(from: Int, to: Int, edge: UInt8 = 0) -> PersonMaskFrame {
        var values = [UInt8](repeating: 0, count: Self.width * Self.height)
        for row in 0..<Self.height {
            for column in from..<to { values[row * Self.width + column] = 255 }
            if to < Self.width { values[row * Self.width + to] = edge }
        }
        return PersonMaskFrame(width: Self.width, height: Self.height, values: values)
    }

    private func value(_ frame: PersonMaskFrame?, column: Int) -> Int {
        Int(frame?.values[column] ?? 0)
    }

    @Test func aShimmeringEdgeSettles() throws {
        var track = PersonMaskTrack()
        var shown: [PersonMaskFrame] = []
        for index in 0..<20 {
            // The edge column jumps between 40 and 120 every frame, as Vision's soft edge does.
            let raw = mask(from: 4, to: 12, edge: index.isMultiple(of: 2) ? 40 : 120)
            shown.append(try #require(track.next(raw, at: Double(index) * Self.frame, epoch: 0).mask))
        }
        let rawSwing = 80
        let steadiedSwing = abs(value(shown[19], column: 12) - value(shown[18], column: 12))
        #expect(steadiedSwing < rawSwing / 2, "the edge still swings \(steadiedSwing) of 255")
        // The person's middle never moves.
        #expect(value(shown[19], column: 8) == 255)
    }

    @Test func aMoveIsFollowedAtOnce() throws {
        var track = PersonMaskTrack()
        _ = track.next(mask(from: 2, to: 8), at: 0, epoch: 0)
        let moved = try #require(track.next(mask(from: 10, to: 16), at: Self.frame, epoch: 0).mask)
        // Where the person went is all person, where they were is none: nothing trails behind.
        #expect(value(moved, column: 12) == 255)
        #expect(value(moved, column: 4) == 0)
    }

    @Test func aFailedFrameKeepsTheLastOutlineThenFades() throws {
        var track = PersonMaskTrack()
        let good = mask(from: 4, to: 12)
        _ = track.next(good, at: 0, epoch: 0)
        // Failed frames every 0.1 s (closer than the gap that starts over).
        let steps = (1...8).map { track.next(nil, at: Double($0) / 10, epoch: 0) }
        let held = steps[3]
        #expect(held.state == .held)
        #expect(held.mask == good)
        let fading = steps[5]
        #expect(fading.state == .fading)
        // Turning into the frame as recorded: around the person goes from 0 toward 255.
        #expect(value(fading.mask, column: 0) > 0 && value(fading.mask, column: 0) < 255)
        let lost = steps[7]
        #expect(lost.state == .lost)
        #expect(lost.mask == nil)
        #expect(lost.state.isFailure && fading.state.isFailure && !held.state.isFailure)
    }

    @Test func aPersonLostByVisionIsHeldAndAPersonGoneIsLetGo() throws {
        var track = PersonMaskTrack()
        let good = mask(from: 4, to: 12)
        let empty = PersonMaskFrame(width: Self.width, height: Self.height, values: [UInt8](repeating: 0, count: Self.width * Self.height))
        var time = 0.0
        _ = track.next(good, at: time, epoch: 0)
        // One empty frame between good ones: held, never shown.
        time += Self.frame
        #expect(track.next(empty, at: time, epoch: 0) == PersonMaskTrack.Step(mask: good, state: .held))
        // Empty for a second: once held and faded, the empty mask is what shows (the person left the frame).
        var last: PersonMaskTrack.Step?
        while time < 1.2 {
            time += Self.frame
            last = track.next(empty, at: time, epoch: 0)
        }
        #expect(last == PersonMaskTrack.Step(mask: empty, state: .found))
    }

    @Test func aSeekOrACutStartsAgain() throws {
        var track = PersonMaskTrack()
        _ = track.next(mask(from: 2, to: 8, edge: 200), at: 0, epoch: 0)
        let afterGap = mask(from: 2, to: 8, edge: 20)
        #expect(track.next(afterGap, at: 1, epoch: 0).mask == afterGap)
        _ = track.next(mask(from: 2, to: 8, edge: 200), at: 1 + Self.frame, epoch: 0)
        #expect(track.next(afterGap, at: 1 + 2 * Self.frame, epoch: 5).mask == afterGap)
        // Nothing before a failed first frame: the frame as recorded.
        var fresh = PersonMaskTrack()
        #expect(fresh.next(nil, at: 0, epoch: 0) == PersonMaskTrack.Step(mask: nil, state: .lost))
    }

    @Test func theSameFramesGiveTheSameMasks() {
        func run() -> [PersonMaskFrame?] {
            var track = PersonMaskTrack()
            return (0..<30).map { index in
                let raw: PersonMaskFrame? = index % 7 == 3 ? nil : mask(from: 3 + index % 3, to: 12, edge: UInt8(index * 8))
                return track.next(raw, at: Double(index) * Self.frame, epoch: 0).mask
            }
        }
        #expect(run() == run())
    }

    @Test func overlapAndChangeMeasureTwoMasks() {
        let first = mask(from: 0, to: 10), second = mask(from: 5, to: 15)
        #expect(abs(first.overlap(with: second) - 5.0 / 15.0) < 0.001)
        #expect(first.overlap(with: first) == 1)
        #expect(abs(first.coverage - 0.5) < 0.001)
        #expect(first.meanChange(from: first) == 0)
        #expect(abs(first.meanChange(from: second) - 0.5) < 0.001)
    }

    @Test func checkJoinsCloseFailuresIntoMoments() {
        let moments = CutoutCheckResult.moments(of: [1, 1.25, 1.5, 3, 3.25], interval: 0.25)
        #expect(moments == [TimeSpan(start: 1, end: 1.75), TimeSpan(start: 3, end: 3.5)])
    }
}
