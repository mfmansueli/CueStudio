//
//  CutFollowingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The time relations of the layers (plan §6, matrix §4), one test per case: what happens to texts, photos and videos,
/// voice-overs, sounds and music when the cuts change (`CutFollowing`, through `EditDocument.commit`) and when a clip is
/// deleted (`TakeEdit.removingClip`), and Undo and Redo bringing back where everything was.
@MainActor
@Suite("Cut following")
struct CutFollowingTests {
    // MARK: - Fixtures

    private static func text(_ span: TimeSpan = TimeSpan(start: 0, end: 1)) -> TextOverlay {
        TextOverlay(role: .title, style: .bold, span: span)
    }

    private static func effect(at start: TimeInterval) -> MusicClip {
        var clip = MusicClip(fileName: "ding.m4a", title: "Ding", fileDuration: 1, start: start, length: 1)
        clip.effect = .ding
        return clip
    }

    private static func music(at start: TimeInterval, length: TimeInterval = 8) -> MusicClip {
        MusicClip(fileName: "m.m4a", title: "Loop", fileDuration: 60, start: start, length: length)
    }

    /// A take of 12 s cut in three clips (0–4, 4–8, 8–12).
    private static func threeClips() -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.timeline.split(atEdited: 4)
        edit.timeline.split(atEdited: 8)
        return edit
    }

    /// The same three clips in a montage: another video of 5 s after them.
    private static func montage() -> TakeEdit {
        var edit = threeClips()
        edit.timeline.insertClip(source: UUID(), duration: 5)
        return edit
    }

    private static func textSpan(_ edit: TakeEdit, _ index: Int = 0) -> TimeSpan? {
        TakeEdit.editedSpan(edit.texts[index].span, anchor: edit.texts[index].clipAnchor, in: edit.timeline)
    }

    private static func close(_ span: TimeSpan?, _ start: TimeInterval, _ end: TimeInterval) -> Bool {
        guard let span else { return false }
        return abs(span.start - start) < 0.01 && abs(span.end - end) < 0.01
    }

    // MARK: - Texts and media over deleted content

    /// Matrix §4, "Texto em trecho apagado (simples)": partly over the deleted clip, it keeps the rest; all of it there, it
    /// goes with it (hidden, pinned to the take's seconds) and the toast counts it.
    @Test func aTextOfOneTakeKeepsWhatIsLeftAndGoesWithAClipItWasOnlyOn() throws {
        var edit = Self.threeClips()
        edit.texts = [Self.text(TimeSpan(start: 3, end: 6)), Self.text(TimeSpan(start: 5, end: 7))]
        let removal = try #require(edit.removingClip(edit.timeline.segments[1].id))
        #expect(Self.close(Self.textSpan(removal.edit, 0), 3, 4))
        #expect(Self.textSpan(removal.edit, 1) == nil)
        #expect(removal.edit.texts.count == 2, "a take's own seconds can come back with a handle")
        #expect(removal.texts == 1)
    }

    /// Matrix §4, "Texto em edição montada com o clipe inicial apagado": the part over the next clip stays (it vanished whole).
    @Test func aMontageTextWhoseFirstClipIsDeletedKeepsThePartOverTheNext() throws {
        var edit = Self.montage()
        var across = Self.text()
        let pinned = edit.pin(TimeSpan(start: 3, end: 6))
        across.clipAnchor = pinned.anchor
        across.span = pinned.span
        var only = Self.text()
        let alone = edit.pin(TimeSpan(start: 1, end: 2))
        only.clipAnchor = alone.anchor
        only.span = alone.span
        edit.texts = [across, only]
        let removal = try #require(edit.removingClip(edit.timeline.segments[0].id))
        #expect(removal.edit.texts.count == 1, "the text only on the deleted clip goes with it")
        #expect(Self.close(Self.textSpan(removal.edit), 0, 2))
        #expect(removal.texts == 1)
    }

    /// Matrix §4, "Mídia que segue os cortes, clipe inicial apagado": the rest stays, its video still in step with the speech.
    @Test func mediaThatFollowsTheCutsKeepsThePartOverTheNextClipInStep() throws {
        var edit = Self.montage()
        var support = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 9.0 / 16, mediaDuration: 20, span: TimeSpan(start: 0, end: 1))
        support.followsCuts = true
        edit.media = [support]
        edit.layMedia(at: 0, over: TimeSpan(start: 3, end: 6))
        let removal = try #require(edit.removingClip(edit.timeline.segments[0].id))
        let pieces = removal.edit.media[0].pieces(in: removal.edit.timeline)
        #expect(pieces.count == 1)
        #expect(Self.close(pieces.first?.edited, 0, 2))
        // The speech's second 4 showed the video's second 1: it still does.
        #expect(abs((pieces.first?.fileStart ?? -1) - 1) < 0.01)
        #expect(removal.videos == 0)
    }

    /// Matrix §4, "Narração em clipe apagado de outra gravação": a voice-over on a deleted clip of another video starts where the
    /// edit picks up (the cut), never at the same second of the take.
    @Test func aVoiceOverOnADeletedClipOfAnotherVideoStartsAtTheCut() throws {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.timeline.split(atEdited: 6)
        let other = UUID()
        let inserted = edit.timeline.insertClip(source: other, duration: 10, at: 1)
        let clipID = try #require(inserted)
        var voice = VoiceOverClip(fileName: "v.m4a", duration: 3, anchor: 2)
        voice.clipAnchor = ClipAnchor(segmentID: clipID, sourceID: other)
        edit.voiceOvers = [voice]
        #expect(Self.close(edit.voiceOvers[0].editedSpan(in: edit.timeline), 8, 11))
        let removal = try #require(edit.removingClip(clipID))
        #expect(Self.close(removal.edit.voiceOvers[0].editedSpan(in: removal.edit.timeline), 6, 9))
        #expect(removal.voiceOvers == 0)
        // Pinned to a clip that is gone, it never falls on the take's own second 2.
        var lost = edit
        lost.timeline = removal.edit.timeline
        #expect(lost.voiceOvers[0].editedSpan(in: lost.timeline) == nil)
    }

    /// Matrix §4, "Narração sob remoção de fala": pauses taken out under it never cut or squeeze it.
    @Test func aVoiceOverPlaysWholeOverSpeechWithPausesTakenOut() {
        var timeline = EditTimeline(sourceDuration: 12)
        let voice = VoiceOverClip(fileName: "v.m4a", duration: 6, anchor: 2)
        let removed = timeline.remove([TimeSpan(start: 3, end: 4), TimeSpan(start: 5, end: 6)])
        #expect(removed)
        #expect(Self.close(voice.editedSpan(in: timeline), 2, 8))
    }

    /// Matrix §4, "Efeitos sonoros em clipe apagado": they go with it (no pile-up at the next clip's start); music stays put.
    @Test func soundEffectsOnADeletedClipGoWithItAndMusicStays() throws {
        var edit = Self.threeClips()
        edit.music = [Self.effect(at: 5), Self.effect(at: 6.5), Self.effect(at: 9), Self.music(at: 5)]
        let removal = try #require(edit.removingClip(edit.timeline.segments[1].id))
        #expect(removal.sounds == 2)
        #expect(removal.edit.music.count == 2)
        #expect(abs(removal.edit.music[0].start - 5) < 0.01, "the effect at 9 s follows its moment to 5 s")
        #expect(removal.edit.music[1].start == 5)
    }

    // MARK: - Freeze, insert and pauses

    /// Matrix §4, "Texto sobre congelamento ou inserção": a freeze frame in its middle, it ends with the speech it was laid over.
    @Test func aTextOverAFreezeFrameEndsWithItsSpeech() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.texts = [Self.text(TimeSpan(start: 2, end: 6))]
        let document = EditDocument(edit)
        var next = document.edit
        next.anchorOverlays()
        next.timeline.split(atEdited: 4)
        next.timeline.insertClip(source: UUID(), duration: 5, span: TimeSpan(start: 0, end: 2), at: 1)
        document.commit(EditSnapshot(next))
        #expect(Self.close(Self.textSpan(document.edit), 2, 8))
        #expect(document.undo())
        #expect(document.edit.texts == edit.texts && document.edit.timeline == edit.timeline)
        #expect(document.redo())
        #expect(Self.close(Self.textSpan(document.edit), 2, 8))
    }

    /// Matrix §4, "Edição simples × montada": a pause taken out under a text shortens it in both (in a montage it slid).
    @Test func aPauseTakenOutUnderATextShortensItInBothKinds() {
        for arranged in [false, true] {
            var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
            if arranged { edit.timeline.insertClip(source: UUID(), duration: 4) }
            var text = Self.text()
            let pinned = edit.pin(TimeSpan(start: 2, end: 8))
            text.clipAnchor = pinned.anchor
            text.span = pinned.span
            edit.texts = [text]
            let document = EditDocument(edit)
            var timeline = document.edit.timeline
            timeline.remove([TimeSpan(start: 4, end: 5)])
            document.commit(timeline)
            #expect(Self.close(Self.textSpan(document.edit), 2, 7), "arranged: \(arranged)")
        }
    }

    // MARK: - Reverse, duplicate, replace

    /// Matrix §4, "Reverter ou duplicar depois de dividir": what plays on a split's right part is found there, though it names
    /// the left part.
    @Test func aSplitsRightPartHoldsWhatIsOnIt() throws {
        var edit = Self.montage()
        var text = Self.text()
        let pinned = edit.pin(TimeSpan(start: 2.5, end: 3.5))
        text.clipAnchor = pinned.anchor
        text.span = pinned.span
        edit.texts = [text]
        var voice = VoiceOverClip(fileName: "v.m4a", duration: 1, anchor: 3)
        voice.clipAnchor = pinned.anchor
        edit.voiceOvers = [voice]
        edit.timeline.split(atEdited: 2)
        let left = edit.timeline.segments[0].id, right = edit.timeline.segments[1].id
        #expect(edit.texts[0].clipAnchor?.segmentID == left)
        #expect(edit.layersStarting(onSegment: right).texts == [0])
        #expect(edit.layersStarting(onSegment: right).voiceOvers == [0])
        #expect(edit.layersStarting(onSegment: left).texts.isEmpty)
    }

    /// Matrix §4, "Substituir ou reverter": captions of the original speech never show over the reversed clip (on purpose:
    /// its words play backwards), and come back when it plays forward again.
    @Test func captionsOfTheSpeechStayOffAReversedClip() {
        var edit = Self.threeClips()
        edit.captions = [CaptionCue(text: "Backwards", start: 5, end: 6)]
        #expect(edit.editedCaptions.count == 1)
        var reversed = edit
        reversed.timeline.replaceSource(ofSegmentAt: 1, with: UUID(), duration: 4, span: TimeSpan(start: 0, end: 4))
        #expect(reversed.editedCaptions.isEmpty)
        reversed.timeline.replaceSource(ofSegmentAt: 1, with: nil, duration: 12, span: TimeSpan(start: 4, end: 8))
        #expect(reversed.editedCaptions.count == 1)
    }

    // MARK: - Music

    /// Matrix §4, "Música sob introdução inserida": it stays in its place (owner, 06/11); moved along only when asked.
    @Test func musicStaysUnderAnInsertedIntroUntilMovedAlong() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.music = [Self.music(at: 0), Self.effect(at: 5)]
        let document = EditDocument(edit)
        var timeline = document.edit.timeline
        timeline.insertClip(source: UUID(), duration: 3, at: 0)
        document.commit(timeline)
        #expect(document.edit.music[0].start == 0, "music keeps its place in the edit")
        #expect(abs(document.edit.music[1].start - 8) < 0.01, "an effect follows its moment")
        let moving = MusicClip.music(startingFrom: 0, in: edit.music, duration: edit.editedDuration)
        #expect(moving.map(\.id) == [edit.music[0].id])
        let moved = MusicClip.moved(document.edit.music, startingFrom: 0, in: edit.editedDuration, by: 3)
        #expect(moved[0].start == 3 && abs(moved[1].start - 8) < 0.01)
    }

    /// Matrix §4, "Música empurrada para depois do fim": it stays in view at the end, where it can be dragged back; Undo puts it
    /// where it was.
    @Test func musicPastTheNewEndStaysInView() throws {
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        edit.timeline.split(atEdited: 10)
        edit.timeline.split(atEdited: 20)
        edit.music = [Self.music(at: 25, length: 10)]
        let removal = try #require(edit.removingClip(edit.timeline.segments[2].id))
        let clip = removal.edit.music[0]
        #expect(clip.span(inEditOf: removal.edit.editedDuration) != nil)
        #expect(abs(clip.start - (20 - MusicClip.minimumDuration)) < 0.01)
        let document = EditDocument(edit)
        document.commit(EditSnapshot(removal.edit))
        #expect(document.undo())
        #expect(document.edit.music[0].start == 25)
    }

    // MARK: - Risks

    /// Matrix §4, "Keyframes depois de mudar velocidade": a faster clip shortens the text, its exit still plays at its new end,
    /// and its keyframes keep their times (never stretched).
    @Test func aFasterClipKeepsATextsExitAndKeyframes() throws {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        var text = Self.text(TimeSpan(start: 2, end: 6))
        text.animation = OverlayAnimation(preset: .inAndOut)
        text.keyframes = [OverlayKeyframe(time: 3, center: .center)]
        edit.texts = [text]
        edit.timeline.setSpeed(2, forSegmentAt: 0)
        let span = try #require(Self.textSpan(edit))
        #expect(Self.close(span, 1, 3))
        let motion = OverlayMotion(
            edit.texts[0].keyframes, animation: edit.texts[0].animation, length: span.duration, base: .init(center: .center, scale: 1, opacity: 1)
        )
        #expect((motion.state(at: span.duration)?.opacity ?? 1) < 0.01)
        #expect(edit.texts[0].keyframes[0].time == 3)
    }

    /// Matrix §4, "Mídia sobre um vão": a clip put in the middle of media that follows the cuts opens a gap in it; its keyframes
    /// after the gap stay on the frames they were set on.
    @Test func keyframesOfMediaStayOnTheirFramesAcrossAGap() throws {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline.insertClip(source: UUID(), duration: 3)
        edit.timeline.split(atEdited: 6)
        var support = MediaOverlay(kind: .video, fileName: "v.mov", aspect: 9.0 / 16, mediaDuration: 20, span: TimeSpan(start: 0, end: 1))
        support.followsCuts = true
        edit.media = [support]
        edit.layMedia(at: 0, over: TimeSpan(start: 4, end: 9))
        // At 3 s of its own time (the video's second 3).
        edit.media[0].keyframes = [OverlayKeyframe(time: 1, center: .center), OverlayKeyframe(time: 3, center: .center)]
        let document = EditDocument(edit)
        var timeline = document.edit.timeline
        timeline.insertClip(source: UUID(), duration: 4, at: 1)
        document.commit(timeline)
        let media = document.edit.media[0]
        #expect(media.pieces(in: document.edit.timeline).count == 2)
        #expect(media.keyframes?.map(\.time) == [1, 7])
        #expect(document.undo())
        #expect(document.edit.media[0].keyframes?.map(\.time) == [1, 3])
    }

    /// Matrix §4, "Transição ao mover o clipe para primeiro": moved to the middle, a clip keeps the transition into it; first,
    /// it has none (nothing comes before it), and Undo brings it back.
    @Test func aClipMovedFirstPlaysFromAHardCutAndUndoBringsItsTransitionBack() {
        var edit = Self.threeClips()
        edit.timeline.setTransition(.dissolve, atJoin: 1)
        let document = EditDocument(edit)
        var later = document.edit.timeline
        later.moveSegment(from: 1, to: 2)
        #expect(later.segments[2].transitionIn == .dissolve)
        var first = document.edit.timeline
        first.moveSegment(from: 1, to: 0)
        document.commit(first)
        #expect(document.edit.timeline.segments[0].transitionIn == .hardCut)
        #expect(document.undo())
        #expect(document.edit.timeline.segments[1].transitionIn == .dissolve)
    }

    // MARK: - Undo and Redo of a deletion

    /// Matrix §4, "Undo e Redo": deleting a clip is one step; Undo brings back the clip, the texts, media, voice-overs and
    /// sounds as they were, Redo the deletion as it was; the step places nothing twice.
    @Test func undoAndRedoOfADeletedClipBringBackEverything() throws {
        var edit = Self.montage()
        var across = Self.text()
        let pinned = edit.pin(TimeSpan(start: 3, end: 6))
        across.clipAnchor = pinned.anchor
        across.span = pinned.span
        var only = Self.text()
        let alone = edit.pin(TimeSpan(start: 1, end: 2))
        only.clipAnchor = alone.anchor
        only.span = alone.span
        edit.texts = [across, only]
        var voice = VoiceOverClip(fileName: "v.m4a", duration: 2, anchor: 1)
        voice.clipAnchor = alone.anchor
        edit.voiceOvers = [voice]
        edit.music = [Self.effect(at: 1), Self.effect(at: 9)]
        let removal = try #require(edit.removingClip(edit.timeline.segments[0].id))
        let document = EditDocument(edit)
        document.commit(EditSnapshot(removal.edit))
        #expect(document.edit.texts == removal.edit.texts && document.edit.voiceOvers == removal.edit.voiceOvers)
        #expect(document.edit.music == removal.edit.music && document.edit.media == removal.edit.media)
        #expect(Self.close(document.edit.voiceOvers.first?.editedSpan(in: document.edit.timeline), 0, 2))
        #expect(document.undo())
        #expect(document.edit.timeline == edit.timeline)
        #expect(document.edit.texts == edit.texts && document.edit.voiceOvers == edit.voiceOvers && document.edit.music == edit.music)
        #expect(document.redo())
        #expect(document.edit.texts == removal.edit.texts && document.edit.music == removal.edit.music)
    }

    /// A handle dragged out and back in one gesture leaves the layers where they were (they follow from where it began).
    @Test func aGestureOutAndBackLeavesTheLayersAsTheyWere() {
        var edit = Self.montage()
        var text = Self.text()
        let pinned = edit.pin(TimeSpan(start: 2, end: 3))
        text.clipAnchor = pinned.anchor
        text.span = pinned.span
        edit.texts = [text]
        let document = EditDocument(edit)
        document.beginChange()
        var out = document.edit.timeline
        out.remove([TimeSpan(start: 1, end: 2.5)])
        document.commit(out)
        document.commit(edit.timeline)
        document.endChange()
        #expect(document.edit.texts == edit.texts)
    }
}
