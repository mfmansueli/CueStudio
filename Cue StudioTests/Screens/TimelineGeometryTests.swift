//
//  TimelineGeometryTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

@Suite("TimelineGeometry")
struct TimelineGeometryTests {
    private let first = UUID()
    private let second = UUID()
    private let text = UUID()
    private let caption = UUID()

    private func input(_ update: (inout TimelineGeometry.Input) -> Void = { _ in }) -> TimelineGeometry.Input {
        var input = TimelineGeometry.Input(duration: 21.6)
        input.clips = [
            TimelineGeometry.ClipInput(id: first, start: 0, duration: 10, sourceStart: 0, sourceEnd: 10, speed: 1, sourceID: nil),
            TimelineGeometry.ClipInput(id: second, start: 10, duration: 11.6, sourceStart: 10, sourceEnd: 21.6, speed: 1, sourceID: nil),
        ]
        update(&input)
        return input
    }

    // MARK: - Cuts

    @Test func aCutHasAMarkThatPicksIt() {
        let geometry = TimelineGeometry(input())
        #expect(geometry.joins.count == 1)
        let join = geometry.joins[0]
        #expect(join.id == second)
        #expect(join.transition == .hardCut)
        // In the middle of the cut, on the video track.
        #expect(abs(join.frame.midX - 440) < 0.001)
        #expect(geometry.hit(at: CGPoint(x: 440, y: join.frame.midY)) == .join(second))
        #expect(geometry.hit(at: CGPoint(x: 300, y: join.frame.midY)) == .clip(first))
    }

    @Test func aCutsMarkShowsItsTransitionAndHidesWhenAClipIsPicked() {
        let dissolved = TimelineGeometry(input { input in
            input.clips[1].transition = .dissolve
            input.selectedJoin = second
        })
        #expect(dissolved.joins.first?.transition == .dissolve)
        #expect(dissolved.joins.first?.isSelected == true)
        let picked = TimelineGeometry(input { $0.selection = .clip(first) })
        #expect(picked.joins.isEmpty)
        // Too short a clip beside it: no room for the mark.
        let short = TimelineGeometry(input { input in
            input.clips[0].duration = 0.4
            input.clips[1].start = 0.4
        })
        #expect(short.joins.isEmpty)
    }

    // MARK: - Lanes

    @Test func restingOrderIsVideoThenTextCaptionsAndAudio() {
        let geometry = TimelineGeometry(input())
        #expect(geometry.lanes.map(\.lane) == [.main, .text, .captions, .audio])
        let main = geometry.lane(.main)
        #expect(main?.y == 28)
        #expect(main?.height == 56)
        #expect(geometry.lane(.text)?.y == CGFloat(28 + 56 + 8))
        #expect(geometry.lane(.text)?.height == 28)
    }

    @Test func musicAndVoiceOverReplaceTheAudioShortcut() {
        let geometry = TimelineGeometry(input { input in
            input.music = [TimelineGeometry.ItemInput(id: UUID(), span: TimeSpan(start: 0, end: 21.6), label: "Morning loop")]
            input.voiceOvers = [TimelineGeometry.ItemInput(id: UUID(), span: TimeSpan(start: 2, end: 4), label: "Voice-over")]
        })
        #expect(geometry.lanes.map(\.lane) == [.main, .text, .captions, .music, .voiceOver])
        #expect(!geometry.ghosts.contains { $0.target == .addAudio })
    }

    @Test func aPanelBringsItsTrackUpAndShrinksTheVideo() {
        let geometry = TimelineGeometry(input { input in
            input.panelIsOpen = true
            input.focusedLane = .captions
        })
        #expect(geometry.lanes.map(\.lane) == [.captions, .main])
        #expect(geometry.lane(.captions)?.y == 22)
        #expect(geometry.lane(.main)?.height == 40)
        #expect(geometry.clips[0].waveformHeight == 10)
    }

    @Test func aPanelWithoutATrackKeepsTheVideoOnTop() {
        let geometry = TimelineGeometry(input { $0.panelIsOpen = true })
        #expect(geometry.lanes.first?.lane == .main)
        #expect(geometry.lane(.main)?.y == 22)
    }

    @Test func smallScreensGetSmallerTracks() {
        let geometry = TimelineGeometry(input { $0.heightClass = .veryCompact })
        #expect(geometry.lane(.main)?.height == 44)
        #expect(geometry.lane(.text)?.height == 22)
    }

    @Test func theSelectedTrackGrows() {
        let geometry = TimelineGeometry(input { input in
            input.texts = [TimelineGeometry.ItemInput(id: text, span: TimeSpan(start: 0.2, end: 3.8), label: "5 comidas de SP")]
            input.selection = .text(text)
        })
        #expect(geometry.lane(.text)?.height == 36)
    }

    // MARK: - Clips

    @Test func clipsSitEdgeToEdgeAtThePointsPerSecond() {
        let geometry = TimelineGeometry(input())
        #expect(geometry.contentWidth == 21.6 * 44)
        #expect(geometry.clips[0].frame.minX == 1)
        #expect(geometry.clips[0].frame.width == CGFloat(10 * 44 - 2))
        #expect(geometry.clips[1].frame.minX == CGFloat(10 * 44 + 1))
        #expect(geometry.clips[0].thumbnailHeight == CGFloat(56 - 14))
    }

    @Test func zoomScalesEverything() {
        let geometry = TimelineGeometry(input { $0.pointsPerSecond = 44 * 5 })
        #expect(geometry.contentWidth == 21.6 * 220)
        #expect(geometry.clips[1].frame.minX == CGFloat(10 * 220 + 1))
    }

    @Test func aPickedClipHasHandlesAndTheRestDims() {
        let geometry = TimelineGeometry(input { $0.selection = .clip(first) })
        #expect(geometry.clips[0].isSelected)
        #expect(!geometry.clips[0].isDimmed)
        #expect(geometry.clips[1].isDimmed)
        #expect(geometry.handles.count == 2)
        let start = geometry.handles[0]
        #expect(start.target == .clip(first, .start))
        #expect(start.frame.width == 16)
        #expect(start.hitFrame.width >= 32)
        // The hit area grows outward, so the clip itself stays tappable.
        #expect(start.hitFrame.maxX == start.frame.maxX)
    }

    @Test func coverBeforeTheStartAndAddAfterTheEnd() {
        let geometry = TimelineGeometry(input())
        #expect(geometry.coverFrame.maxX == -20)
        #expect(geometry.coverFrame.width == 50)
        #expect(geometry.addFrame.minX == geometry.contentWidth + 14)
    }

    // MARK: - Items

    @Test func itemsSitOnTheirTracksWithKeyframes() throws {
        let geometry = TimelineGeometry(input { input in
            input.texts = [TimelineGeometry.ItemInput(id: text, span: TimeSpan(start: 1, end: 4), label: "Title", keyframes: [1, 2.5])]
            input.captions = [TimelineGeometry.ItemInput(id: caption, span: TimeSpan(start: 5.2, end: 7.1), label: "Mas valem cada centavo.")]
        })
        let title = try #require(geometry.items.first { $0.id == text })
        #expect(title.frame.minX == 44)
        #expect(title.frame.minY == geometry.lane(.text)?.y)
        #expect(title.keyframeOffsets == [0, 1.5 * 44])
        let line = try #require(geometry.items.first { $0.id == caption })
        #expect(line.frame.minY == geometry.lane(.captions)?.y)
    }

    @Test func hiddenCaptionsLeaveAShortcut() {
        let geometry = TimelineGeometry(input { input in
            input.captions = [TimelineGeometry.ItemInput(id: caption, span: TimeSpan(start: 5.2, end: 7.1), label: "Line")]
            input.showsCaptions = false
        })
        #expect(!geometry.items.contains { $0.kind == .caption })
        #expect(geometry.ghosts.contains { $0.target == .captions && $0.label == "Captions off" })
    }

    @Test func emptyTracksShowShortcuts() {
        let geometry = TimelineGeometry(input())
        #expect(geometry.ghosts.map(\.target) == [.addText, .captions, .addAudio])
        #expect(geometry.ghosts.map(\.label) == ["Add text", "Auto captions", "Add audio"])
    }

    @Test func musicAndVoiceOverHaveNoHandles() {
        let music = UUID()
        let geometry = TimelineGeometry(input { input in
            input.music = [TimelineGeometry.ItemInput(id: music, span: TimeSpan(start: 0, end: 21.6), label: "Morning loop")]
            input.selection = .music(music)
        })
        #expect(geometry.handles.isEmpty)
    }

    @Test func aRecordingGrowsOnTheVoiceOverTrack() throws {
        let geometry = TimelineGeometry(input { $0.recording = TimeSpan(start: 3, end: 5) })
        #expect(geometry.lanes.contains { $0.lane == .voiceOver })
        let recording = try #require(geometry.items.first { $0.kind == .recording })
        #expect(recording.frame.width == 88)
    }

    // MARK: - Hits

    @Test func tapsHitInOrder() {
        let geometry = TimelineGeometry(input { input in
            input.texts = [TimelineGeometry.ItemInput(id: text, span: TimeSpan(start: 1, end: 4), label: "Title")]
            input.pauses = [TimelineGeometry.PauseInput(id: caption, span: TimeSpan(start: 4, end: 5), isMarked: true)]
        })
        let main = geometry.lane(.main)!
        #expect(geometry.hit(at: CGPoint(x: -40, y: main.y + 10)) == .cover)
        #expect(geometry.hit(at: CGPoint(x: geometry.addFrame.midX, y: geometry.addFrame.midY)) == .addClip)
        #expect(geometry.hit(at: CGPoint(x: 4.5 * 44, y: main.y + 10)) == .pause(caption))
        #expect(geometry.hit(at: CGPoint(x: 2 * 44, y: main.y + 10)) == .clip(first))
        #expect(geometry.hit(at: CGPoint(x: 2 * 44, y: geometry.lane(.text)!.y + 5)) == .item(.text, text))
        #expect(geometry.hit(at: CGPoint(x: 15 * 44, y: geometry.lane(.text)!.y + 5)) == nil)
    }

    @Test func handlesComeFirst() throws {
        let geometry = TimelineGeometry(input { $0.selection = .clip(second) })
        let end = try #require(geometry.handles.last)
        #expect(geometry.handle(at: CGPoint(x: end.frame.midX, y: end.frame.midY))?.target == .clip(second, .end))
        #expect(geometry.handle(at: CGPoint(x: 5 * 44, y: end.frame.midY)) == nil)
    }

    // MARK: - Snapping

    @Test func snapTimesAreCutsEdgesAndKeyframes() {
        let geometry = TimelineGeometry(input { input in
            input.texts = [TimelineGeometry.ItemInput(id: text, span: TimeSpan(start: 1, end: 4), label: "Title", keyframes: [2.5])]
            input.captions = [TimelineGeometry.ItemInput(id: caption, span: TimeSpan(start: 5.2, end: 7.1), label: "Line")]
        })
        #expect(geometry.snapTimes == [0, 1, 2.5, 4, 5.2, 7.1, 10, 21.6])
    }
}
