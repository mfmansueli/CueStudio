//
//  TimelineChangeTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// What a creator's step moves on the timeline (`TimelineChange`): an item added grows and its track flashes, a clip deleted
/// shrinks out and the ones after it close the space, a pick springs in, a track brought under the video rises; a whole new set,
/// a trim or the first drawing move nothing.
@Suite("Timeline · what a step moves")
struct TimelineChangeTests {
    private let clips = [UUID(), UUID(), UUID()]
    private let caption = UUID()

    /// Three 5 s clips one after the other (`kept` of them), a caption, and `update` on top.
    private func geometry(
        keeping kept: [Int] = [0, 1, 2], _ update: (inout TimelineGeometry.Input) -> Void = { _ in }
    ) -> TimelineGeometry {
        var input = TimelineGeometry.Input(duration: TimeInterval(kept.count * 5))
        input.clips = kept.enumerated().map { place, index in
            TimelineGeometry.ClipInput(
                id: clips[index], start: TimeInterval(place * 5), duration: 5, sourceStart: TimeInterval(index * 5),
                sourceEnd: TimeInterval(index * 5 + 5), speed: 1, sourceID: nil
            )
        }
        input.captions = [TimelineGeometry.ItemInput(id: caption, span: TimeSpan(start: 0, end: 2), label: "Hello")]
        input.tracks = TimelineTrackChoice()
        update(&input)
        return TimelineGeometry(input)
    }

    private func text(_ id: UUID, at start: TimeInterval = 3) -> TimelineGeometry.ItemInput {
        TimelineGeometry.ItemInput(id: id, span: TimeSpan(start: start, end: start + 2), label: "Title")
    }

    @Test func theFirstDrawingMovesNothing() {
        #expect(TimelineChange(from: nil, to: geometry()) == .none)
        #expect(TimelineChange(from: geometry(), to: geometry()) == .none)
    }

    @Test func anAddedTextGrowsAndItsTrackFlashes() {
        let id = UUID()
        let change = TimelineChange(from: geometry(), to: geometry { $0.texts = [text(id)] })
        #expect(change.added == [id])
        #expect(change.addedLanes == [.text])
        #expect(change.removed.isEmpty)
        #expect(change.shifts.isEmpty)
    }

    /// An item on a track that isn't out still counts: it grows once its track is brought.
    @Test func anItemOnAHiddenTrackStillCounts() {
        let id = UUID()
        let change = TimelineChange(
            from: geometry { $0.tracks = TimelineTrackChoice(current: .captions) },
            to: geometry { $0.tracks = TimelineTrackChoice(current: .captions); $0.texts = [text(id)] }
        )
        #expect(change.added == [id])
    }

    @Test func aWholeNewSetIsDrawnInPlace() {
        let lines = (0..<10).map { _ in UUID() }
        let change = TimelineChange(from: geometry(), to: geometry { input in
            input.captions = lines.enumerated().map { index, id in
                TimelineGeometry.ItemInput(id: id, span: TimeSpan(start: Double(index), end: Double(index) + 1), label: "Line")
            }
        })
        #expect(change.added.isEmpty)
        #expect(change.addedLanes.isEmpty)
        // The caption the set replaced is drawn away in place too.
        #expect(change.removed.isEmpty)
    }

    @Test func aDeletedClipShrinksOutAndTheOnesAfterCloseTheSpace() {
        let old = geometry()
        let new = geometry(keeping: [0, 2])
        let change = TimelineChange(from: old, to: new)
        #expect(change.removed == [clips[1]])
        #expect(change.added.isEmpty)
        // The last clip was 5 s further on: it slides back from there.
        #expect(change.shifts[clips[2]] == 5 * new.pointsPerSecond)
        #expect(change.shifts[clips[0]] == nil)
    }

    @Test func aDeletedTextShrinksOutAndNothingSlides() {
        let id = UUID()
        let change = TimelineChange(from: geometry { $0.texts = [text(id)] }, to: geometry())
        #expect(change.removed == [id])
        #expect(change.shifts.isEmpty)
    }

    @Test func aTrimOrAZoomMovesNothing() {
        let trimmed = geometry { $0.clips[1].duration = 3 }
        #expect(TimelineChange(from: geometry(), to: trimmed) == .none)
        let zoomed = geometry { $0.pointsPerSecond = TimelineGeometry.basePointsPerSecond * 2 }
        #expect(TimelineChange(from: geometry(), to: zoomed) == .none)
    }

    @Test func aPickSpringsInOnce() {
        let id = UUID()
        let none = geometry { $0.texts = [text(id)] }
        let picked = geometry { $0.texts = [text(id)]; $0.selection = .text(id) }
        #expect(TimelineChange(from: none, to: picked).picked)
        #expect(!TimelineChange(from: picked, to: picked).picked)
        // Letting go isn't a pick.
        #expect(!TimelineChange(from: picked, to: none).picked)
        #expect(TimelineChange(from: none, to: geometry { $0.texts = [text(id)]; $0.selection = .clip(clips[0]) }).picked)
    }

    @Test func aTrackBroughtUnderTheVideoRisesIntoPlace() {
        let texts = geometry()
        let captions = geometry { $0.tracks = TimelineTrackChoice(current: .captions) }
        #expect(TimelineChange(from: texts, to: captions).arrivedLane == .captions)
        // Every track coming out, or going away, isn't a track brought.
        let out = geometry { $0.tracks = TimelineTrackChoice(current: .text, isExpanded: true) }
        #expect(TimelineChange(from: texts, to: out).arrivedLane == nil)
        #expect(TimelineChange(from: out, to: captions).arrivedLane == nil)
    }
}
