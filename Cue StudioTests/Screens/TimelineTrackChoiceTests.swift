//
//  TimelineTrackChoiceTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// One track under the video at a time (`TimelineTrackChoice`): collapsed, the timeline is the video track and the current
/// track, ▾ beside its icon, and the preview gets the room the others took; ▾ brings every track out in place. Every track is
/// as tall, so choosing one or picking an item never moves the video.
@Suite("Timeline · one track at a time")
struct TimelineTrackChoiceTests {
    private let every: [TimelineLane] = [.main, .media, .text, .captions, .music, .voiceOver]

    // MARK: - The rule

    @Test func collapsedShowsTheVideoAndTheCurrentTrack() {
        var choice = TimelineTrackChoice()
        #expect(choice.current == .text)
        #expect(choice.lanes(from: every) == [.main, .text])
        choice.isExpanded = true
        #expect(choice.lanes(from: every) == every)
        choice.choose(.music)
        #expect(choice == TimelineTrackChoice(current: .music, isExpanded: false))
        #expect(choice.lanes(from: every) == [.main, .music])
    }

    @Test func aTrackThatWentShowsTextsAndComesBackWithTheUndo() {
        var choice = TimelineTrackChoice(current: .music)
        let musicGone: [TimelineLane] = [.main, .media, .text, .captions, .voiceOver]
        #expect(choice.lanes(from: musicGone) == [.main, .text])
        // Kept: the music brought back by Undo is current again.
        #expect(choice.lanes(from: every) == [.main, .music])
        // The shortcut to add audio gives way to what was added.
        choice.current = .audio
        #expect(choice.shown(in: every) == .music)
        // The video track is never chosen.
        choice.choose(.main)
        #expect(choice.current == .audio)
    }

    @Test func aTrackIsBroughtByTheFirstOfItsKindTheEditHas() {
        var choice = TimelineTrackChoice(current: .text, isExpanded: true)
        choice.bring(anyOf: [.music, .voiceOver, .audio], in: [.main, .media, .text, .captions, .voiceOver])
        #expect(choice == TimelineTrackChoice(current: .voiceOver, isExpanded: false))
        // A track whose first item is on its way is current already, and shows once the item is there.
        choice.bring(anyOf: [.blur], in: every)
        #expect(choice.current == .blur)
        #expect(choice.shown(in: every) == .text)
        #expect(choice.shown(in: every + [.blur]) == .blur)
        // The current track stays when it is one of them.
        var voice = TimelineTrackChoice(current: .voiceOver, isExpanded: true)
        voice.bring(anyOf: [.music, .voiceOver, .audio], in: every)
        #expect(voice == TimelineTrackChoice(current: .voiceOver, isExpanded: false))
    }

    // MARK: - The timeline

    private func input(_ choice: TimelineTrackChoice, _ update: (inout TimelineGeometry.Input) -> Void = { _ in }) -> TimelineGeometry.Input {
        var input = TimelineGeometry.Input(duration: 20)
        input.clips = [TimelineGeometry.ClipInput(id: UUID(), start: 0, duration: 20, sourceStart: 0, sourceEnd: 20, speed: 1, sourceID: nil)]
        input.tracks = choice
        update(&input)
        return input
    }

    @Test func collapsedTheCurrentTrackSitsUnderTheVideoWithTheChevron() throws {
        let geometry = TimelineGeometry(input(TimelineTrackChoice(current: .captions)))
        #expect(geometry.lanes.map(\.lane) == [.main, .captions])
        let main = try #require(geometry.lane(.main))
        let captions = try #require(geometry.lane(.captions))
        #expect(captions.y == main.y + main.height + 8)
        let chooser = try #require(geometry.chooser)
        #expect(chooser.lane == .captions)
        #expect(!chooser.isExpanded)
        // A comfortable reach, the gutter's whole cell, that never takes the video track.
        #expect(captions.height == 44)
        #expect(chooser.hitFrame.width >= TimelineGeometry.chooserReach)
        #expect(chooser.hitFrame.width >= TimelineGeometry.gutterWidth)
        #expect(chooser.hitFrame.height >= TimelineGeometry.chooserReach)
        #expect(chooser.hitFrame.minY >= main.y + main.height)
        #expect(geometry.chooserHit(atViewportX: 20, y: captions.y + 14))
        #expect(geometry.chooserHit(atViewportX: TimelineGeometry.gutterWidth - 1, y: captions.y + captions.height - 2))
        #expect(!geometry.chooserHit(atViewportX: 60, y: captions.y + 14))
        #expect(!geometry.chooserHit(atViewportX: 20, y: main.y + 20))
    }

    @Test func outEveryTrackShowsInItsPlaceAndTheChevronPointsUp() throws {
        let geometry = TimelineGeometry(input(TimelineTrackChoice(current: .captions, isExpanded: true)))
        #expect(geometry.lanes.map(\.lane) == [.main, .media, .text, .captions, .audio])
        let chooser = try #require(geometry.chooser)
        #expect(chooser.lane == .captions)
        #expect(chooser.isExpanded)
        // Its reach stays between the tracks above and below: a tap on them chooses them.
        let text = try #require(geometry.lane(.text))
        let audio = try #require(geometry.lane(.audio))
        #expect(chooser.hitFrame.minY >= text.y + text.height)
        #expect(chooser.hitFrame.maxY <= audio.y)
        #expect(geometry.laneHit(atViewportX: 20, y: text.y + 14, viewportWidth: 402) == .lane(.text))
    }

    @Test func aPanelAboutOneTrackShowsItAsBeforeWithoutTheChevron() {
        let geometry = TimelineGeometry(input(TimelineTrackChoice(current: .captions)) { input in
            input.panelIsOpen = true
            input.focusedLane = .text
        })
        #expect(geometry.lanes.map(\.lane) == [.text, .main])
        #expect(geometry.chooser == nil)
        // As tall as the video track there.
        #expect(geometry.lane(.text)?.height == 40)
        #expect(geometry.lane(.main)?.height == 40)
    }

    /// Out, every track takes the height the editor gave them (`EditorLayout.openLaneHeight`), 6 pt apart; collapsed, the
    /// current one is as tall as a track alone, whatever that height.
    @Test func outTheTracksTakeTheHeightTheEditorGaveThem() throws {
        let out = TimelineGeometry(input(TimelineTrackChoice(current: .captions, isExpanded: true)) { $0.openLaneHeight = 36 })
        let media = try #require(out.lane(.media))
        let text = try #require(out.lane(.text))
        #expect(out.lanes.filter { $0.lane != .main }.allSatisfy { $0.height == 36 })
        #expect(text.y == media.y + 36 + 6)
        let collapsed = TimelineGeometry(input(TimelineTrackChoice(current: .captions)) { $0.openLaneHeight = 36 })
        #expect(collapsed.lane(.captions)?.height == 44)
        // A panel open with every track out: never taller than the video track there.
        let underAPanel = TimelineGeometry(input(TimelineTrackChoice(current: .captions, isExpanded: true)) { input in
            input.openLaneHeight = 44
            input.panelIsOpen = true
        })
        #expect(underAPanel.lane(.captions)?.height == 40)
    }

    @Test func withoutAChoiceEveryTrackShows() {
        var plain = input(TimelineTrackChoice())
        plain.tracks = nil
        let geometry = TimelineGeometry(plain)
        #expect(geometry.lanes.map(\.lane) == [.main, .media, .text, .captions, .audio])
        #expect(geometry.chooser == nil)
    }

    /// The room kept collapsed is the ruler, the video track and one track: a picked photo fits it whole.
    @Test func theCollapsedRoomFitsATrackPicked() {
        // The ruler, the video track and its space, the photos track, and the room under it.
        let room: CGFloat = 28 + 56 + 8 + 44 + 8
        #expect(abs(TimelineGeometry.collapsedHeight(heightClass: .regular) - room) < 0.001)
        let photo = UUID()
        let geometry = TimelineGeometry(input(TimelineTrackChoice(current: .media)) { input in
            input.media = [TimelineGeometry.ItemInput(id: photo, span: TimeSpan(start: 1, end: 4), label: "Photo")]
            input.selection = .media(photo)
        })
        #expect(geometry.contentHeight <= TimelineGeometry.collapsedHeight(heightClass: .regular))
    }

    // MARK: - The editor's room

    /// Usable heights of the screens the editor is checked on (`EditorLayoutTests`).
    private let screens: [CGFloat] = [603, 684, 715, 734, 816]

    @Test func collapsedTheVideoGetsTheRoomTheOtherTracksTook() {
        // The demo's tracks on an iPhone 17: 260 pt of timeline out (every track showing, at 28 pt), 144 collapsed.
        let out = EditorLayout(usableHeight: 734, timelineLanes: every)
        let collapsed = EditorLayout(usableHeight: 734, timelineLanes: every, collapsesTimeline: true)
        #expect(out.timeline == 260)
        #expect(out.openLaneHeight == 28)
        #expect(collapsed.timeline == 144)
        #expect(collapsed.preview == out.preview + 116)
        for usable in screens {
            let out = EditorLayout(usableHeight: usable, timelineLanes: every)
            let collapsed = EditorLayout(usableHeight: usable, timelineLanes: every, collapsesTimeline: true)
            #expect(collapsed.preview > out.preview, "\(usable)")
            #expect(collapsed.timeline >= TimelineGeometry.collapsedHeight(heightClass: collapsed.heightClass) - 0.01, "\(usable)")
            #expect(abs(collapsed.preview + collapsed.playerBar + collapsed.timeline + collapsed.toolbar - usable) < 0.5, "\(usable)")
        }
    }

    /// Collapsed, the room is the same whatever track is current and whatever else the edit has: music or a voice-over coming
    /// or going never moves the video.
    @Test func collapsedTracksComingOrGoingNeverMoveTheVideo() {
        let new = TimelineGeometry.lanes(hasBlurs: false, hasMusic: false, hasVoice: false)
        for usable in screens {
            let few = EditorLayout(usableHeight: usable, timelineLanes: new, collapsesTimeline: true)
            let more = EditorLayout(usableHeight: usable, timelineLanes: every, collapsesTimeline: true)
            #expect(few.preview == more.preview, "\(usable)")
            #expect(few.timeline == more.timeline, "\(usable)")
        }
    }
}
