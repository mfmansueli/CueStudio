//
//  TimelineRevealTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// A finger dragging the timeline up or down (`TimelineGeometry.Input.reveal`, `EditorLayout.timelineReveal`): every track is
/// laid out between where it rests collapsed and where it sits out, the others fading in, ▾ turning as far, the timeline as
/// tall as the tracks; at either end everything is where it rests, so letting go never jumps. Let go, it settles on a spring
/// (`TimelineRevealSpring`).
@Suite("Timeline · dragging every track out")
struct TimelineRevealTests {
    private let every = TimelineGeometry.lanes(hasBlurs: true, hasMusic: true, hasVoice: true)
    /// One item on each track (text, photo, Blur area, caption, music, voice-over).
    private let ids = (0..<6).map { _ in UUID() }

    /// The busiest edit (all six tracks under the video, a text on Texts), Texts current, on an iPhone 17's tracks (28 pt out).
    private func input(reveal: CGFloat?, expanded: Bool = false) -> TimelineGeometry.Input {
        var input = TimelineGeometry.Input(duration: 20)
        let span = TimeSpan(start: 1, end: 4)
        input.texts = [TimelineGeometry.ItemInput(id: ids[0], span: span, label: "Title")]
        input.media = [TimelineGeometry.ItemInput(id: ids[1], span: span, label: "Photo")]
        input.blurs = [TimelineGeometry.ItemInput(id: ids[2], span: span, label: "Face")]
        input.captions = [TimelineGeometry.ItemInput(id: ids[3], span: span, label: "Hello")]
        input.music = [TimelineGeometry.ItemInput(id: ids[4], span: TimeSpan(start: 0, end: 20), label: "Song")]
        input.voiceOvers = [TimelineGeometry.ItemInput(id: ids[5], span: span, label: "Voice")]
        input.tracks = TimelineTrackChoice(current: .text, isExpanded: expanded)
        input.openLaneHeight = 28
        input.reveal = reveal
        return input
    }

    private func frames(_ geometry: TimelineGeometry) -> [TimelineLane: TimelineGeometry.LaneFrame] {
        Dictionary(uniqueKeysWithValues: geometry.lanes.map { ($0.lane, $0) })
    }

    @Test func atEitherEndTheTracksAreWhereTheyRest() {
        let collapsed = TimelineGeometry(input(reveal: nil))
        let start = TimelineGeometry(input(reveal: 0))
        #expect(start.lanes.count == every.count)
        #expect(frames(start)[.text] == frames(collapsed)[.text])
        #expect(start.contentHeight == collapsed.contentHeight)
        // The others wait under the current track, unseen.
        for frame in start.lanes where frame.lane != .main && frame.lane != .text {
            #expect(frame.y == frames(collapsed)[.text]?.y)
            #expect(frame.opacity == 0)
        }
        let out = TimelineGeometry(input(reveal: nil, expanded: true))
        let end = TimelineGeometry(input(reveal: 1, expanded: true))
        #expect(end.lanes == out.lanes)
        #expect(end.contentHeight == out.contentHeight)
        #expect(end.items == out.items)
    }

    @Test func theOthersFadeInAsTheyComeOutAndTheCurrentOneShowsThroughout() {
        for (reveal, fade) in [(0.1, 0.0), (0.4, 0.5), (0.8, 1.0)] as [(CGFloat, CGFloat)] {
            let geometry = TimelineGeometry(input(reveal: reveal))
            #expect(frames(geometry)[.text]?.opacity == 1)
            #expect(abs((frames(geometry)[.music]?.opacity ?? -1) - fade) < 0.001, "\(reveal)")
            // An item takes its track's.
            #expect(abs((geometry.items.first { $0.kind == .music }?.opacity ?? -1) - fade) < 0.001, "\(reveal)")
            #expect(geometry.items.first { $0.kind == .text }?.opacity == 1)
        }
    }

    @Test func theTracksMoveAndShrinkAsFarAsTheFingerWent() {
        let collapsed = frames(TimelineGeometry(input(reveal: nil)))
        let out = frames(TimelineGeometry(input(reveal: nil, expanded: true)))
        let half = frames(TimelineGeometry(input(reveal: 0.5)))
        for lane in every where lane != .main {
            let from = collapsed[.text]!
            let to = out[lane]!
            #expect(abs(half[lane]!.y - (from.y + to.y) / 2) < 0.001, "\(lane)")
            #expect(abs(half[lane]!.height - (44 + 28) / 2) < 0.001, "\(lane)")
        }
        // Past either end the timeline stretches, the tracks don't.
        #expect(TimelineGeometry(input(reveal: 1.1, expanded: true)).lanes == TimelineGeometry(input(reveal: 1, expanded: true)).lanes)
        #expect(TimelineGeometry(input(reveal: -0.1)).lanes == TimelineGeometry(input(reveal: 0)).lanes)
    }

    @Test func theChevronTurnsAsFar() {
        #expect(TimelineGeometry(input(reveal: 0.3)).chooser?.turn == 0.3)
        #expect(TimelineGeometry(input(reveal: nil)).chooser?.turn == 0)
        #expect(TimelineGeometry(input(reveal: nil, expanded: true)).chooser?.turn == 1)
    }

    @Test func withAPanelOpenItIsIgnored() {
        var dragged = input(reveal: 0.5)
        dragged.panelIsOpen = true
        var resting = input(reveal: nil)
        resting.panelIsOpen = true
        #expect(TimelineGeometry(dragged).lanes == TimelineGeometry(resting).lanes)
    }

    /// The editor gives the timeline the tracks' height all the way (an iPhone 17, all six tracks: 144 to 294 pt).
    @Test func theTimelineIsAsTallAsTheTracks() {
        let collapsed = EditorLayout(usableHeight: 734, timelineLanes: every, collapsesTimeline: true)
        let out = EditorLayout(usableHeight: 734, timelineLanes: every)
        #expect(collapsed.collapsedTimeline == 144)
        #expect(collapsed.openTimeline == 294)
        #expect(EditorLayout(usableHeight: 734, timelineLanes: every, collapsesTimeline: true, timelineReveal: 0) == collapsed)
        #expect(EditorLayout(usableHeight: 734, timelineLanes: every, timelineReveal: 1) == out)
        for reveal in [0.25, 0.5, 0.75] as [CGFloat] {
            let layout = EditorLayout(usableHeight: 734, timelineLanes: every, timelineReveal: reveal)
            #expect(abs(layout.timeline - TimelineGeometry(input(reveal: reveal)).contentHeight) < 0.01, "\(reveal)")
            #expect(abs(layout.preview + layout.playerBar + layout.timeline + layout.toolbar - 734) < 0.5)
        }
        // Never past the video's minimum, however far it stretches.
        let stretched = EditorLayout(usableHeight: 520, timelineLanes: every, timelineReveal: 1.2)
        #expect(stretched.preview >= EditorLayout.previewMinimum(for: 520) - 0.01)
    }

    @Test func letGoItSettlesWhereItWasHeadedFromWhereItWas() {
        let spring = TimelineRevealSpring(from: 0.6, to: 1, velocity: 3)
        #expect(abs(spring.value(at: 0) - 0.6) < 0.000_001)
        #expect(!spring.isSettled(at: 0.05))
        let settled = stride(from: 0.0, through: 1.2, by: 1.0 / 120).first { spring.isSettled(at: $0) }
        #expect((settled ?? 2) < 0.8)
        #expect(abs(spring.value(at: settled ?? 0) - 1) < 0.002)
    }

    @Test func itPassesTheMarkALittleButNotWithReduceMotion() {
        let times = stride(from: 0.0, through: 1.2, by: 1.0 / 240)
        let lively = TimelineRevealSpring(from: 0.9, to: 1, velocity: 4)
        let peak = times.map { lively.value(at: $0) }.max() ?? 0
        #expect(peak > 1)
        #expect(peak < 1.2)
        let calm = TimelineRevealSpring(from: 0.9, to: 1, velocity: 4, passesTheMark: false)
        #expect(calm.velocity == 0)
        #expect((times.map { calm.value(at: $0) }.max() ?? 2) <= 1.000_1)
    }

    @Test func aThrowKeepsOnlySomeOfItsSpeedAndOnlyTowardWhereItGoes() {
        #expect(TimelineRevealSpring(from: 0.4, to: 1, velocity: 30).velocity == TimelineRevealSpring.maximumSpeed)
        #expect(TimelineRevealSpring(from: 0.4, to: 1, velocity: -5).velocity == 0)
        #expect(TimelineRevealSpring(from: 0.4, to: 0, velocity: -2).velocity == -2)
    }
}
