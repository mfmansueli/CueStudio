//
//  TimelineMediaLaneTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The timeline's media track: its own lane right under the video, only when there is media, a little taller for the frames;
/// texts keep theirs (with their hint when there are none); a short space between two supports of the split screen is
/// marked, and a tap on the mark picks the support after it.
@Suite("Timeline media lane")
struct TimelineMediaLaneTests {
    private func input(_ media: [TimelineGeometry.ItemInput] = []) -> TimelineGeometry.Input {
        var input = TimelineGeometry.Input(duration: 21.6)
        input.clips = [TimelineGeometry.ClipInput(id: UUID(), start: 0, duration: 21.6, sourceStart: 0, sourceEnd: 21.6, speed: 1, sourceID: nil)]
        input.media = media
        return input
    }

    private func support(_ start: TimeInterval, _ end: TimeInterval, layout: MediaLayout = .split) -> TimelineGeometry.ItemInput {
        var item = TimelineGeometry.ItemInput(id: UUID(), span: TimeSpan(start: start, end: end), label: "Video")
        item.strip = TimelineGeometry.MediaStrip(
            fileName: "v.mov", isVideo: true, pieces: [MediaPiece(edited: TimeSpan(start: start, end: end), fileStart: 0)], layout: layout
        )
        return item
    }

    @Test func mediaHasItsLaneEvenEmptySayingHowToAddTheFirst() {
        let empty = TimelineGeometry(input())
        #expect(empty.lanes.map(\.lane) == [.main, .media, .text, .captions, .audio])
        #expect(empty.ghosts.contains { $0.target == .lane(.media) && $0.label == "Tap to add a photo or video" })
        let geometry = TimelineGeometry(input([support(2, 4)]))
        #expect(geometry.lanes.map(\.lane) == [.main, .media, .text, .captions, .audio])
        #expect(!geometry.ghosts.contains { $0.target == .lane(.media) })
        let lane = geometry.lane(.media)
        #expect(lane?.y == CGFloat(28 + 56 + 6))
        #expect(lane?.height == 44)
        #expect(geometry.items.first?.frame.minY == lane?.y)
        #expect(geometry.items.first?.strip?.layout == .split)
        // Texts keep their hint.
        #expect(geometry.ghosts.map(\.target).contains(.lane(.text)))
    }

    @Test func aShortSpaceBetweenSupportsIsMarkedAndATapPicksTheNext() throws {
        let after = support(4.3, 6)
        let geometry = TimelineGeometry(input([support(2, 4), after, support(7, 9), support(9, 10, layout: .window)]))
        // 0.3 s is marked; a whole second isn't (plainly on purpose); a window is no support.
        #expect(geometry.gaps.count == 1)
        let gap = try #require(geometry.gaps.first)
        #expect(gap.id == after.id)
        #expect(geometry.hit(at: CGPoint(x: gap.frame.midX, y: gap.frame.midY)) == .gap(after.id))
    }
}
