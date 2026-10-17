//
//  TakeEditCoverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The cover's frame is a picture of one recording: picked on any clip of a montage, it stays on that recording and second
/// whatever the edit does (order, copies, cuts, speed), and says so once no clip shows it.
@Suite("Cover frame in a montage")
struct TakeEditCoverTests {
    private let other = UUID()

    /// The take (10 s) cut at 4 s, then 6 s of another recording at the end: [take 0–4][take 4–10][other 0–6].
    private func montage() -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.timeline.split(atEdited: 4)
        edit.sources = [ClipSource(fileName: "other.mov", duration: 6, title: "Video")]
        edit.sources[0].id = other
        edit.timeline.insertClip(source: other, duration: 6)
        return edit
    }

    @Test func aFramePickedOnAnotherRecordingIsOfThatRecording() {
        let edit = montage()
        // 12 s into the edit is 2 s into the other recording.
        let frame = edit.coverFrame(atEdited: 12)
        #expect(frame.sourceID == other)
        #expect(frame.segmentID == edit.timeline.segments[2].id)
        #expect(abs(frame.time - 2) < 0.001)
        #expect(abs((edit.editedTime(of: frame) ?? -1) - 12) < 0.001)
    }

    @Test func itFollowsItsClipWhenTheOrderChanges() {
        var edit = montage()
        let frame = edit.coverFrame(atEdited: 12)
        edit.timeline.moveSegment(from: 2, to: 0)
        // The other recording now plays first: its second 2 is at 2 s.
        #expect(abs((edit.editedTime(of: frame) ?? -1) - 2) < 0.001)
        #expect(!edit.coverFrameLeftTheEdit)
    }

    @Test func aFramePickedOnACopyStaysOnTheCopy() throws {
        var edit = montage()
        let original = edit.timeline.segments[2].id
        let duplicated = edit.timeline.duplicateSegment(id: original)
        let copy = try #require(duplicated)
        // Picked 1 s into the copy (which starts at 16 s).
        let frame = edit.coverFrame(atEdited: 17)
        #expect(frame.segmentID == copy)
        #expect(edit.clip(showing: frame)?.segment.id == copy)
        // The copy goes: the original clip still shows that second.
        edit.timeline.removeSegment(id: copy)
        #expect(edit.clip(showing: frame)?.segment.id == original)
        #expect(abs((edit.editedTime(of: frame) ?? -1) - 11) < 0.001)
    }

    @Test func speedDoesNotChangeThePictureOnlyWhereItPlays() {
        var edit = montage()
        let frame = edit.coverFrame(atEdited: 12)
        edit.timeline.setSpeed(2, forSegmentAt: 2)
        #expect(abs(frame.time - 2) < 0.001)
        // 2 s of the recording at 2× is 1 s into the clip.
        #expect(abs((edit.editedTime(of: frame) ?? -1) - 11) < 0.001)
    }

    @Test func aSplitClipStillShowsTheFrame() {
        var edit = montage()
        let frame = edit.coverFrame(atEdited: 8)
        edit.timeline.split(atEdited: 6)
        #expect(edit.clip(showing: frame) != nil)
        #expect(abs((edit.editedTime(of: frame) ?? -1) - 8) < 0.001)
    }

    @Test func aRemovedPartLeavesTheCoverAsItWasAndSaysSo() {
        var edit = montage()
        let frame = edit.coverFrame(atEdited: 12)
        edit.cover = VideoCover(source: .clipFrame(frame))
        edit.timeline.removeSegment(id: edit.timeline.segments[2].id)
        #expect(edit.coverFrameLeftTheEdit)
        #expect(edit.editedTime(of: frame) == nil)
        // The picture is still the same recording and second.
        #expect(edit.cover?.source.frame == frame)
    }

    @Test func coversSavedBeforeMontagesAreFramesOfTheTake() throws {
        let json = #"{"source":{"frame":{"_0":2.5}},"title":"Hi","titleY":0.2,"style":"bold"}"#
        let cover = try JSONDecoder().decode(VideoCover.self, from: Data(json.utf8))
        #expect(cover.source.frame == CoverFrame(sourceID: nil, segmentID: nil, time: 2.5))
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.cover = cover
        #expect(abs((edit.editedTime(of: try #require(cover.source.frame)) ?? -1) - 2.5) < 0.001)
    }

    @Test func aClipFrameSurvivesSavingAndOpening() throws {
        let frame = CoverFrame(sourceID: other, segmentID: UUID(), time: 3.25)
        let cover = VideoCover(source: .clipFrame(frame))
        let decoded = try JSONDecoder().decode(VideoCover.self, from: JSONEncoder().encode(cover))
        #expect(decoded.source == .clipFrame(frame))
    }
}
