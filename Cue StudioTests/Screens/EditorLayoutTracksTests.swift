//
//  EditorLayoutTracksTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// With every track out, the timeline grows with its tracks (`EditorLayout`'s `timelineLanes`): every track shows down to the
/// audio one, each new track taking its room from the video, which never goes below its minimum; picking an item or opening a
/// panel never moves the video. Collapsed is `TimelineTrackChoiceTests`.
@Suite("EditorLayout · tracks")
struct EditorLayoutTracksTests {
    /// Usable heights of the screens the editor is checked on (`EditorLayoutTests`).
    private let screens: [CGFloat] = [603, 684, 715, 734, 816]

    private let starting = TimelineGeometry.lanes(hasBlurs: false, hasMusic: false, hasVoice: false)
    private let every = TimelineGeometry.lanes(hasBlurs: true, hasMusic: true, hasVoice: true)

    @Test func aNewEditCollapsedGivesTheVideoMoreRoomThanTheTimelinesOwnShare() {
        #expect(starting == [.main, .media, .text, .captions, .audio])
        for usable in screens {
            let collapsed = EditorLayout(usableHeight: usable, timelineLanes: starting, collapsesTimeline: true)
            #expect(collapsed.preview > EditorLayout(usableHeight: usable).preview, "\(usable)")
        }
    }

    @Test func everyTrackShowsDownToTheAudioOneOnEveryIPhone() {
        #expect(every == [.main, .media, .blur, .text, .captions, .music, .voiceOver])
        for usable in screens {
            let layout = EditorLayout(usableHeight: usable, timelineLanes: every)
            let tracks = TimelineGeometry.restingHeight(of: every, heightClass: layout.heightClass)
            #expect(layout.timeline >= tracks - 0.01, "\(usable)")
            #expect(layout.preview >= EditorLayout.previewMinimum(for: usable) - 0.01, "\(usable)")
            #expect(abs(layout.preview + layout.playerBar + layout.timeline + layout.toolbar - usable) < 0.5, "\(usable)")
        }
    }

    @Test func eachTrackAddedTakesItsRoomFromTheVideo() {
        let usable: CGFloat = 734
        let blur = TimelineGeometry.lanes(hasBlurs: true, hasMusic: false, hasVoice: false)
        let blurAndAudio = TimelineGeometry.lanes(hasBlurs: true, hasMusic: true, hasVoice: true)
        let new = EditorLayout(usableHeight: usable, timelineLanes: starting)
        let withBlur = EditorLayout(usableHeight: usable, timelineLanes: blur)
        let withMore = EditorLayout(usableHeight: usable, timelineLanes: blurAndAudio)
        #expect(withBlur.preview < new.preview)
        #expect(withMore.preview < withBlur.preview)
        #expect(withMore.timeline == TimelineGeometry.restingHeight(of: blurAndAudio, heightClass: .regular))
        // A track gone gives the room back.
        #expect(EditorLayout(usableHeight: usable, timelineLanes: starting) == new)
    }

    @Test func inAShortWindowTheVideoKeepsItsMinimumAndTheTracksScroll() {
        let usable: CGFloat = 520
        let layout = EditorLayout(usableHeight: usable, timelineLanes: every)
        #expect(abs(layout.preview - EditorLayout.previewMinimum(for: usable)) < 0.01)
        #expect(layout.timeline < TimelineGeometry.restingHeight(of: every, heightClass: layout.heightClass))
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

    /// The height the editor makes room for is what the tracks take with nothing open, the picked one's grown included: picking
    /// an item never moves the video, and nothing is cut off.
    @Test func theRoomMadeIsWhatTheTracksTakeWithAnyOnePicked() {
        var input = TimelineGeometry.Input(duration: 20)
        let text = UUID()
        let song = UUID()
        input.texts = [TimelineGeometry.ItemInput(id: text, span: TimeSpan(start: 1, end: 4), label: "Hi")]
        input.music = [TimelineGeometry.ItemInput(id: song, span: TimeSpan(start: 0, end: 20), label: "Song")]
        let lanes = TimelineGeometry(input).lanes.map(\.lane)
        #expect(lanes == TimelineGeometry.lanes(hasBlurs: false, hasMusic: true, hasVoice: false))
        let room = TimelineGeometry.restingHeight(of: lanes, heightClass: .regular)
        let growth = EditorHeightClass.regular.selectedLaneHeight - EditorHeightClass.regular.laneHeight
        #expect(TimelineGeometry(input).contentHeight == room - growth)
        input.selection = .music(song)
        #expect(TimelineGeometry(input).contentHeight == room)
        input.selection = .text(text)
        #expect(TimelineGeometry(input).contentHeight == room)
    }
}
