//
//  SplitScreenCaptionTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Captions with a split screen: a support's own voice, heard on its own, is captioned where it shows (and follows the cuts
/// like the support), the main video's lines under it hide meanwhile and come back when it's off; "On the seam" puts the
/// lines said while a support shows on the seam, the rest where the creator put them.
@Suite("Split screen captions")
struct SplitScreenCaptionTests {
    private static func line(_ text: String, _ start: TimeInterval, _ end: TimeInterval, source: UUID? = nil) -> CaptionCue {
        var cue = CaptionCue(text: text, start: start, end: end)
        cue.sourceID = source
        return cue
    }

    private static func support(_ span: TimeSpan, length: TimeInterval = 10) -> MediaOverlay {
        var media = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 9.0 / 16, mediaDuration: length, span: span)
        media.layout = .split
        media.followsCuts = true
        media.hasSound = true
        return media
    }

    @Test func aSupportsVoiceShowsWhereItShowsAndTheSpeechUnderItWaits() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        var support = Self.support(TimeSpan(start: 4, end: 8))
        support.mediaStart = 1
        support.captionsItsVoice = true
        edit.media = [support]
        edit.captions = [
            Self.line("before", 1, 3), Self.line("under it", 5, 6), Self.line("after", 9, 11),
            // Its own voice, at 2 to 3 s of its file: 1 s after it starts showing, so 5 to 6 s of the edit.
            Self.line("its voice", 2, 3, source: support.id),
            // Said in a part of its file that doesn't show: never shown.
            Self.line("not shown", 8, 9, source: support.id),
        ]
        let shown = edit.editedCaptions
        #expect(shown.map(\.text) == ["before", "its voice", "after"])
        #expect(shown.first { $0.text == "its voice" }.map { abs($0.start - 5) < 0.001 && abs($0.end - 6) < 0.001 } == true)
        // Off, the speech's line is back.
        edit.media[0].captionsItsVoice = nil
        #expect(edit.editedCaptions.map(\.text).contains("under it"))
    }

    @Test func aSupportsVoiceFollowsTheCutsLikeTheSupport() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline = EditTimeline(sourceDuration: 20, keeping: [TimeSpan(start: 0, end: 5), TimeSpan(start: 7, end: 20)])
        var support = Self.support(TimeSpan(start: 4, end: 10))
        support.captionsItsVoice = true
        edit.media = [support]
        // At 4 s of its file: 4 s after it was laid (8 s of the speech), cut-out 2 s and all, so 6 s of the edit.
        edit.captions = [Self.line("later", 4, 5, source: support.id), Self.line("cut out", 1.5, 2.5, source: support.id)]
        let shown = edit.editedCaptions
        #expect(shown.map(\.text) == ["later"])
        #expect(shown.first.map { abs($0.start - 6) < 0.001 } == true)
    }

    @Test func onTheSeamOnlyTheLinesSaidDuringASupportMove() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.splitScreen.setLayout(SplitLayout(ratio: .sixtyForty, larger: .main))
        edit.media = [Self.support(TimeSpan(start: 4, end: 8))]
        edit.showsCaptions = true
        edit.captions = [Self.line("outside", 1, 3), Self.line("during", 5, 6)]
        let frame = CGSize(width: 1080, height: 1920)
        func centerY(of text: String, in edit: TakeEdit) -> CGFloat? {
            let line = edit.editedCaptions.first { $0.text == text }
            guard let line, let overlay = EditedComposition.captionOverlays(for: edit, frame: frame)
                .first(where: { $0.span?.contains(line.start + 0.01) ?? false }) else { return nil }
            return frame.height - overlay.origin.y - overlay.size.height / 2
        }
        let before = centerY(of: "during", in: edit)
        let outside = centerY(of: "outside", in: edit)
        edit.splitScreen.captionsOnSeam = true
        // 60/40 with the support (smaller) on top: the seam at 40%.
        #expect(centerY(of: "during", in: edit).map { abs($0 - 0.4 * 1920) < 2 } == true)
        #expect(centerY(of: "during", in: edit) != before)
        #expect(centerY(of: "outside", in: edit) == outside)
        // Side by side there's no seam across: nothing moves.
        edit.splitScreen.setLayout(SplitLayout(arrangement: .sideBySide))
        #expect(centerY(of: "during", in: edit) == before)
    }
}
