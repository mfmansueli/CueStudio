//
//  EditorLayoutTracksTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// With every track out (`EditorLayout`'s `timelineLanes`), every track shows, none to scroll to: they share the room that
/// leaves the video at least as tall as everything under it, from a track's own height down to `openLaneMinimum`, and past
/// that the timeline grows past half the screen (only past the video's minimum do they scroll). Picking an item or opening a
/// panel never moves the video. Collapsed is `TimelineTrackChoiceTests`; a drag between the two is `TimelineRevealTests`.
@Suite("EditorLayout · tracks")
struct EditorLayoutTracksTests {
    /// Usable heights of the screens the editor is checked on (`EditorLayoutTests`).
    private let screens: [CGFloat] = [603, 684, 715, 734, 816]

    private let starting = TimelineGeometry.lanes(hasBlurs: false, hasMusic: false, hasVoice: false)
    private let every = TimelineGeometry.lanes(hasBlurs: true, hasMusic: true, hasVoice: true)

    @Test func aNewEditCollapsedGivesTheVideoMoreRoomThanEveryTrackOut() {
        #expect(starting == [.main, .media, .text, .captions, .audio])
        for usable in screens {
            let collapsed = EditorLayout(usableHeight: usable, timelineLanes: starting, collapsesTimeline: true)
            #expect(collapsed.preview > EditorLayout(usableHeight: usable).preview, "\(usable)")
        }
    }

    @Test func outANewEditsVideoIsAtLeastAsTallAsEverythingUnderIt() {
        for usable in screens {
            let layout = EditorLayout(usableHeight: usable, timelineLanes: starting)
            #expect(layout.preview >= layout.playerBar + layout.timeline + layout.toolbar - 0.01, "\(usable)")
            #expect(abs(layout.preview + layout.playerBar + layout.timeline + layout.toolbar - usable) < 0.5, "\(usable)")
        }
    }

    /// Every track of the busiest edit shows out on every iPhone, none to scroll to, the video above its minimum.
    @Test func outEveryTrackShowsOnEveryIPhone() {
        #expect(every == [.main, .media, .blur, .text, .captions, .music, .voiceOver])
        for usable in screens {
            for lanes in [starting, every] {
                let layout = EditorLayout(usableHeight: usable, timelineLanes: lanes)
                let tracks = TimelineGeometry.openHeight(of: lanes, heightClass: layout.heightClass, laneHeight: layout.openLaneHeight)
                #expect(abs(layout.timeline - tracks) < 0.01, "\(usable) \(lanes.count)")
                #expect(layout.preview >= EditorLayout.previewMinimum(for: usable) - 0.01, "\(usable) \(lanes.count)")
                #expect(abs(layout.preview + layout.playerBar + layout.timeline + layout.toolbar - usable) < 0.5, "\(usable)")
                #expect(layout.openLaneHeight >= layout.heightClass.openLaneMinimum, "\(usable)")
                #expect(layout.openLaneHeight <= layout.heightClass.laneHeight, "\(usable)")
            }
        }
    }

    /// A new edit's four tracks all show out, on every iPhone, as tall as the room lets them be.
    @Test func aNewEditsTracksAllShowOutOnEveryIPhone() {
        let heights: [CGFloat: CGFloat] = [603: 24, 684: 33, 715: 33, 734: 36, 816: 44]
        for usable in screens {
            let layout = EditorLayout(usableHeight: usable, timelineLanes: starting)
            #expect(layout.openLaneHeight == heights[usable], "\(usable)")
            let tracks = TimelineGeometry.openHeight(of: starting, heightClass: layout.heightClass, laneHeight: layout.openLaneHeight)
            #expect(layout.timeline >= tracks - 0.01, "\(usable)")
        }
        // An iPhone 17: 36 pt tracks, a 258 pt timeline, and the video (368 pt) taller than the 366 under it.
        let iPhone17 = EditorLayout(usableHeight: 734, timelineLanes: starting)
        #expect(iPhone17.timeline == 258)
        #expect(iPhone17.preview == 368)
    }

    @Test func aTrackAddedShrinksTheTracksBeforeTheVideo() {
        let usable: CGFloat = 816
        let blur = TimelineGeometry.lanes(hasBlurs: true, hasMusic: false, hasVoice: false)
        let new = EditorLayout(usableHeight: usable, timelineLanes: starting)
        let withBlur = EditorLayout(usableHeight: usable, timelineLanes: blur)
        #expect(withBlur.openLaneHeight < new.openLaneHeight)
        #expect(withBlur.preview >= usable / 2 - 0.01)
        // A track gone gives the room back.
        #expect(EditorLayout(usableHeight: usable, timelineLanes: starting) == new)
    }

    /// Past the least a track gets, the timeline grows past half the screen and the video gives the room (owner, 28/10/2026);
    /// only past the video's minimum do the tracks scroll under the ruler.
    @Test func pastTheLeastTheTimelineGrowsPastHalf() {
        // An iPhone 17 with all six tracks: 28 pt each, a 294 pt timeline, a 332 pt video (the half would have been 259).
        let layout = EditorLayout(usableHeight: 734, timelineLanes: every)
        #expect(layout.openLaneHeight == 28)
        #expect(layout.timeline == 294)
        #expect(layout.preview == 332)
        let short = EditorLayout(usableHeight: 520, timelineLanes: every)
        #expect(short.preview >= EditorLayout.previewMinimum(for: 520) - 0.01)
        #expect(short.timeline < TimelineGeometry.openHeight(of: every, heightClass: short.heightClass, laneHeight: short.openLaneHeight))
    }

    @Test func aPanelOpeningNeverMakesTheVideoBigger() {
        for usable in screens {
            let resting = EditorLayout(usableHeight: usable, timelineLanes: every)
            for size in [EditorPanelSize.mini, .medium] {
                for focus in [false, true] {
                    let open = EditorLayout(usableHeight: usable, panel: size, panelFocusesLane: focus, timelineLanes: every)
                    #expect(open.preview <= resting.preview + 0.01, "\(usable) \(size)")
                    #expect(open.preview >= EditorLayout.previewMinimum(for: usable) - 0.01, "\(usable) \(size)")
                }
            }
        }
    }

    /// Every track under the video is as tall, the picked one's too: picking an item never moves anything, out or collapsed.
    @Test func pickingAnItemNeverChangesATracksHeight() {
        var input = TimelineGeometry.Input(duration: 20)
        let text = UUID()
        let song = UUID()
        input.texts = [TimelineGeometry.ItemInput(id: text, span: TimeSpan(start: 1, end: 4), label: "Hi")]
        input.music = [TimelineGeometry.ItemInput(id: song, span: TimeSpan(start: 0, end: 20), label: "Song")]
        input.openLaneHeight = 36
        for tracks in [TimelineTrackChoice(current: .music, isExpanded: true), TimelineTrackChoice(current: .music)] {
            input.tracks = tracks
            input.selection = nil
            let resting = TimelineGeometry(input)
            input.selection = .music(song)
            #expect(TimelineGeometry(input).lanes == resting.lanes)
            input.selection = .text(text)
            #expect(TimelineGeometry(input).lanes == resting.lanes)
        }
        input.selection = nil
        input.tracks = TimelineTrackChoice(current: .music)
        #expect(TimelineGeometry(input).contentHeight == TimelineGeometry.collapsedHeight(heightClass: .regular))
    }
}
