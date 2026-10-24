//
//  MediaPiecesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What a photo or video laid over the take does when the speech under it changes (`MediaOverlay.pieces`): splitting a clip
/// changes nothing, a stretch cut out of the speech is cut out of it too and what follows stays in step, another recording's
/// clip put in between plays without it, a clip's speed never speeds it up, and it never plays past its file. Media added
/// before plays straight on, as it always did.
@Suite("Media follows the speech")
struct MediaPiecesTests {
    private static func video(span: TimeSpan, length: TimeInterval = 20, follows: Bool? = true) -> MediaOverlay {
        var media = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 9.0 / 16, mediaDuration: length, span: span)
        media.followsCuts = follows
        return media
    }

    @Test func splittingAClipChangesNothing() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        let media = Self.video(span: TimeSpan(start: 2, end: 8))
        let before = media.pieces(in: timeline)
        let didSplit = timeline.split(atEdited: 5)
        #expect(didSplit)
        let after = media.pieces(in: timeline)
        #expect(before == [MediaPiece(edited: TimeSpan(start: 2, end: 8), fileStart: 0)])
        #expect(after.count == 2)
        #expect(after.first?.edited.start == 2)
        #expect(after.last?.edited.end == 8)
        // The file plays on without a jump at the split.
        #expect(abs((media.fileTime(at: 6, in: timeline) ?? -1) - 4) < 0.001)
    }

    @Test func aStretchCutFromTheSpeechIsCutFromTheMediaAndTheRestStaysInStep() throws {
        // 5 to 7 s of the main video removed, under a support laid from 2 to 10 s.
        let timeline = EditTimeline(sourceDuration: 12, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 7, end: 12)])
        let support = Self.video(span: TimeSpan(start: 2, end: 10))
        let pieces = support.pieces(in: timeline)
        #expect(pieces.count == 2)
        #expect(pieces[0] == MediaPiece(edited: TimeSpan(start: 2, end: 5), fileStart: 0))
        // From 7 s of the speech (5 s of the edit), second 5 of the support: its 3 to 5 s left with the cut.
        #expect(abs(pieces[1].edited.start - 5) < 0.001)
        #expect(abs(pieces[1].edited.end - 8) < 0.001)
        #expect(abs(pieces[1].fileStart - 5) < 0.001)
        // A later support moves back with the speech.
        let later = Self.video(span: TimeSpan(start: 10, end: 11))
        #expect(later.pieces(in: timeline).map(\.edited) == [TimeSpan(start: 8, end: 9)])
    }

    @Test func mediaAddedBeforePlaysStraightOn() throws {
        let timeline = EditTimeline(sourceDuration: 12, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 7, end: 12)])
        let old = Self.video(span: TimeSpan(start: 2, end: 10), follows: nil)
        #expect(old.pieces(in: timeline) == [MediaPiece(edited: TimeSpan(start: 2, end: 8), fileStart: 0)])
        #expect(old.editedSpan(in: timeline) == TimeSpan(start: 2, end: 8))
    }

    @Test func aCutOverItsStartTakesItsStartToo() throws {
        let timeline = EditTimeline(sourceDuration: 12, keeping: [TimeSpan(start: 0, end: 2), TimeSpan(start: 4, end: 12)])
        let support = Self.video(span: TimeSpan(start: 3, end: 8))
        let pieces = support.pieces(in: timeline)
        #expect(pieces.count == 1)
        // It shows from where the speech picks up (4 s of the speech, 2 s of the edit), one second into its file.
        #expect(abs(pieces[0].edited.start - 2) < 0.001)
        #expect(abs(pieces[0].fileStart - 1) < 0.001)
    }

    @Test func aFasterClipNeverSpeedsTheMediaUp() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        let didSplit = timeline.split(atEdited: 4)
        #expect(didSplit)
        let didSetSpeed = timeline.setSpeed(2, forSegmentAt: 1)
        #expect(didSetSpeed)
        let support = Self.video(span: TimeSpan(start: 2, end: 8))
        let pieces = support.pieces(in: timeline)
        // 2 s at 1× then 4 s of speech at 2× (2 s of the edit): it shows 4 s, at its own speed, without a jump.
        #expect(pieces.count == 2)
        #expect(abs(pieces[1].edited.start - 4) < 0.001)
        #expect(abs(pieces[1].edited.end - 6) < 0.001)
        #expect(abs(pieces[1].fileStart - 2) < 0.001)
        for piece in pieces {
            #expect(abs((piece.fileEnd - piece.fileStart) - piece.edited.duration) < 0.001)
        }
    }

    @Test func aSlowerClipShowsMoreButNeverPastTheFile() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        let didSetSpeed = timeline.setSpeed(0.5, forSegmentAt: 0)
        #expect(didSetSpeed)
        // 6 s of speech at half speed is 12 s of the edit; the file has 5.
        let support = Self.video(span: TimeSpan(start: 2, end: 8), length: 5)
        let pieces = support.pieces(in: timeline)
        #expect(pieces.count == 1)
        #expect(abs(pieces[0].edited.start - 4) < 0.001)
        #expect(abs(pieces[0].edited.duration - 5) < 0.001)
    }

    @Test func aClipInsertedInBetweenPlaysWithoutItAndItPicksUpAfter() throws {
        var timeline = EditTimeline(sourceDuration: 20)
        let didSplit = timeline.split(atEdited: 6)
        #expect(didSplit)
        let first = timeline.segments[0].id
        let other = UUID()
        let didInsert = timeline.insertClip(source: other, duration: 4, at: 1) != nil
        #expect(didInsert)
        var support = Self.video(span: TimeSpan(start: 4, end: 9))
        support.clipAnchor = ClipAnchor(segmentID: first, sourceID: nil)
        let pieces = support.pieces(in: timeline)
        #expect(pieces.count == 2)
        #expect(pieces[0] == MediaPiece(edited: TimeSpan(start: 4, end: 6), fileStart: 0))
        // The inserted 4 s play alone; then the speech goes on from 6 s and the support from its second 2.
        #expect(abs(pieces[1].edited.start - 10) < 0.001)
        #expect(abs(pieces[1].edited.end - 13) < 0.001)
        #expect(abs(pieces[1].fileStart - 2) < 0.001)
    }

    @Test func laidAcrossIntoAnotherRecordingItPlaysOnAsLaid() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        let first = timeline.segments[0].id
        let didInsert = timeline.insertClip(source: UUID(), duration: 6) != nil
        #expect(didInsert)
        var support = Self.video(span: TimeSpan(start: 8, end: 12))
        support.clipAnchor = ClipAnchor(segmentID: first, sourceID: nil)
        #expect(support.pieces(in: timeline) == [MediaPiece(edited: TimeSpan(start: 8, end: 12), fileStart: 0)])
    }

    @Test func thePartPickedStartsTheFile() throws {
        let timeline = EditTimeline(sourceDuration: 12, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 7, end: 12)])
        var support = Self.video(span: TimeSpan(start: 2, end: 10))
        support.mediaStart = 3
        let pieces = support.pieces(in: timeline)
        #expect(abs(pieces[0].fileStart - 3) < 0.001)
        #expect(abs(pieces[1].fileStart - 8) < 0.001)
    }

    @Test func aPhotoShowsOverItsPieces() throws {
        let timeline = EditTimeline(sourceDuration: 12, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 7, end: 12)])
        var photo = MediaOverlay(kind: .photo, fileName: "p.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 4, end: 9))
        photo.followsCuts = true
        #expect(photo.pieces(in: timeline).map(\.edited) == [TimeSpan(start: 4, end: 5), TimeSpan(start: 5, end: 7)])
    }

    @Test func theEditListsTheUnionAndThePieces() throws {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.timeline = EditTimeline(sourceDuration: 12, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 7, end: 12)])
        edit.media = [Self.video(span: TimeSpan(start: 2, end: 10))]
        let placed = try #require(edit.placedMedia(in: edit.timeline).first)
        #expect(placed.span == TimeSpan(start: 2, end: 8))
        #expect(placed.pieces.count == 2)
        #expect(edit.editedMedia(in: edit.timeline).first?.span == TimeSpan(start: 2, end: 8))
    }
}
