//
//  QuickEditTranscriptEditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Edit by text: words in play order, a cut that keeps the pause before the words and drops the one after, captions and what is
/// pinned to the words following the cut, put back, one undo step, and fixing a caption's text never cutting anything.
@MainActor
@Suite("Quick edit · Edit by text")
struct QuickEditTranscriptEditTests {
    /// "So today I want to show you three habits" over 0–4.5 s of a 10 s take, one word every half second (0.35 s long).
    private static let said = ["So", "today", "I", "want", "to", "show", "you", "three", "habits"]

    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 10
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 10
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        viewModel.edit.captionTranscript = CaptionTranscript(words: words, languageCode: "en")
        viewModel.change { $0.captions = [CaptionCue(words: words)] }
        return (viewModel, player)
    }

    @Test func aCutKeepsThePauseBeforeAndDropsTheOneAfter() {
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        let listed = words.enumerated().map { index, word in
            TranscriptWord(
                id: "\(index)", text: word.text, sourceID: nil, span: TimeSpan(start: word.start, end: word.end), index: index,
                segmentID: nil, editedStart: word.start
            )
        }
        // "I want to": from just before "I" (1.0) to just before "show" (2.5).
        let cut = TranscriptEditing.cut(from: listed[2], to: listed[4], transcript: words, recordingLength: 10)
        #expect(abs(cut.start - 0.95) < 0.000_1)
        #expect(abs(cut.end - 2.45) < 0.000_1)
        // Never into the word before: "today" ends at 0.85.
        #expect(cut.start >= 0.85)
        // The last words: a short tail kept.
        let end = TranscriptEditing.cut(from: listed[8], to: listed[8], transcript: words, recordingLength: 10)
        #expect(abs(end.end - (4.35 + TranscriptEditing.tail)) < 0.000_1)
    }

    @Test func cuttingWordsCutsTheVideoAndTheirCaptionsInOneStep() async throws {
        let (viewModel, player) = await makeViewModel()
        #expect(viewModel.hasTranscript)
        #expect(viewModel.transcriptWords.map(\.text) == Self.said)
        viewModel.tapTranscriptWord(at: 2)
        #expect(player.currentTime == 1)
        viewModel.tapTranscriptWord(at: 4)
        #expect(viewModel.selectedTranscriptWords.map(\.text) == ["I", "want", "to"])
        let steps = viewModel.history.past.count
        viewModel.cutSelectedWords()
        #expect(viewModel.history.past.count == steps + 1)
        #expect(abs(viewModel.edit.editedDuration - 8.5) < 0.000_1)
        #expect(viewModel.transcriptSelection == nil)
        // Listed crossed out, and gone from the caption.
        #expect(viewModel.transcriptWords.filter(\.isRemoved).map(\.text) == ["I", "want", "to"])
        // The line shows on both sides of the cut, without the cut words.
        #expect(viewModel.edit.editedCaptions.map(\.text).joined(separator: " ") == "So today show you three habits")
        // Put back.
        viewModel.tapTranscriptWord(at: 2)
        viewModel.tapTranscriptWord(at: 4)
        viewModel.restoreSelectedWords()
        #expect(abs(viewModel.edit.editedDuration - 10) < 0.000_1)
        viewModel.undo()
        #expect(abs(viewModel.edit.editedDuration - 8.5) < 0.000_1)
    }

    /// The pick has a start and an end: the first tap is the start, the next the end (in either order), and Pick again starts over.
    @Test func thePickHasAStartAndAnEndAndStartsOver() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.tapTranscriptWord(at: 5)
        #expect(viewModel.selectedTranscriptWords.map(\.text) == ["show"])
        // The end tapped before the start: still every word between them.
        viewModel.tapTranscriptWord(at: 3)
        #expect(viewModel.selectedTranscriptWords.map(\.text) == ["want", "to", "show"])
        viewModel.clearTranscriptSelection()
        #expect(viewModel.transcriptSelection == nil)
        #expect(viewModel.selectedTranscriptWords.isEmpty)
        viewModel.tapTranscriptWord(at: 7)
        #expect(viewModel.selectedTranscriptWords.map(\.text) == ["three"])
    }

    @Test func fixingCaptionTextNeverCuts() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.sheet = .transcript
        viewModel.tapTranscriptWord(at: 7)
        let duration = viewModel.edit.editedDuration
        viewModel.fixCaptionOfSelectedWords()
        #expect(viewModel.edit.editedDuration == duration)
        #expect(viewModel.sheet == nil)
        #expect(viewModel.panel == .captions)
        #expect(viewModel.selection == .caption(try #require(viewModel.edit.captions.first?.id)))
    }

    @Test func wordsOfAnotherRecordingAreCutInThatRecording() async throws {
        let (viewModel, _) = await makeViewModel()
        let other = UUID()
        var source = ClipSource(fileName: "other.mov", duration: 4, title: "Take 2")
        source.id = other
        var next = viewModel.edit
        next.sources = [source]
        next.timeline.insertClip(source: other, duration: 4)
        var theirs = CaptionTranscript(words: [CaptionWord(text: "Hello", start: 1, end: 1.4), CaptionWord(text: "there", start: 1.6, end: 2)],
                                       languageCode: "en")
        theirs.sourceID = other
        next.sourceTranscripts = [theirs]
        viewModel.commit(EditSnapshot(next))
        viewModel.edit.sourceTranscripts = [theirs]
        let words = viewModel.transcriptWords
        let hello = try #require(words.firstIndex { $0.text == "Hello" })
        viewModel.tapTranscriptWord(at: hello)
        viewModel.cutSelectedWords()
        let pieces = viewModel.edit.timeline.segments.filter { $0.sourceID == other }
        #expect(pieces.allSatisfy { !$0.span.overlaps(TimeSpan(start: 1.05, end: 1.5)) })
        // The take is untouched.
        #expect(viewModel.edit.timeline.segments.filter { $0.sourceID == nil }.map(\.span) == [TimeSpan(start: 0, end: 10)])
    }
}

/// Video templates: captions, texts and motion in one undo step; the words, the lines and the graphics stay; a hook with the
/// script's title when there was no text.
@MainActor
@Suite("Quick edit video templates")
struct QuickEditVideoTemplateTests {
    @Test func aTemplateRestylesEverythingInOneStepAndKeepsTheWords() async throws {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.change { $0.captions = [CaptionCue(text: "Real talk", start: 1, end: 2)] }
        viewModel.addGraphic(.arrow)
        let before = viewModel.edit
        let steps = viewModel.history.past.count
        viewModel.applyVideoTemplate(.boldHook)
        #expect(viewModel.history.past.count == steps + 1)
        // Bold hook's captions: heavy type on a violet band behind each line, bigger, the word being said in yellow.
        let captions = try #require(viewModel.edit.captionCollection)
        #expect(captions.theme == .pop)
        #expect(captions.customLook == nil)
        #expect(captions.accent == .yellow)
        #expect(captions.sizeScale > 1)
        #expect(viewModel.edit.captionAnimation == .highlight)
        #expect(viewModel.edit.captions == before.captions)
        // A hook with the title opens the video; the arrow is untouched.
        let hook = try #require(viewModel.edit.texts.first { $0.graphic == nil })
        #expect(hook.role == .hook)
        #expect(!hook.text.isEmpty)
        #expect(hook.animation?.preset == .pop)
        #expect(viewModel.edit.texts.first { $0.graphic != nil } == before.texts.first)
        // Another template restyles the hook, keeping its words.
        viewModel.applyVideoTemplate(.story)
        #expect(viewModel.edit.texts.filter { $0.graphic == nil }.count == 1)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.text == hook.text)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.preset == .editorial)
        #expect(viewModel.appliedVideoTemplate == .story)
        viewModel.undo()
        #expect(viewModel.appliedVideoTemplate == .boldHook)
        viewModel.undo()
        #expect(viewModel.appliedVideoTemplate == nil)
        #expect(viewModel.edit.texts == before.texts)
        #expect(viewModel.edit.captionCollection == before.captionCollection)
    }
}

/// Freeze frame: the clip is split at the playhead and the frame plays there as a clip of its own, with the clip's look, in
/// one undo step; a failure leaves the edit as it was.
@MainActor
@Suite("Quick edit freeze frame")
struct QuickEditFreezeFrameTests {
    private func makeViewModel(editor: FakeTakeEditor) -> QuickEditViewModel {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 10
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        editor.duration = 10
        return QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
    }

    @Test func theFrameUnderThePlayheadHoldsAsAClip() async throws {
        let editor = FakeTakeEditor()
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        viewModel.change { snapshot in
            var segment = snapshot.timeline.segments[0]
            var look = ClipLook()
            look.exposure = 0.3
            segment.look = look
            snapshot.timeline.replaceSegment(segment)
        }
        viewModel.player.seek(to: 4)
        let before = viewModel.edit
        await viewModel.freezeFrame()
        let timeline = viewModel.edit.timeline
        #expect(timeline.segments.count == 3)
        #expect(abs((editor.stillClips.first?.time ?? 0) - 4) < 0.001)
        let frozen = timeline.segments[1]
        #expect(frozen.sourceID == viewModel.edit.sources.first?.id)
        #expect(viewModel.edit.sources.first?.fileName == "still-1.mov")
        #expect(abs(frozen.duration - QuickEditViewModel.freezeLength) < 0.001)
        #expect(frozen.look == before.timeline.segments[0].look)
        #expect(abs(timeline.editedDuration - (10 + QuickEditViewModel.freezeLength)) < 0.001)
        #expect(abs(timeline.segments[2].sourceStart - 4) < 0.001)
        viewModel.undo()
        #expect(viewModel.edit.timeline == before.timeline)
    }

    /// The cuts changed while the frame was being made: nothing is added or taken away, and the creator is told.
    @Test func aFrameFreezesNothingWhenTheVideoChangedMeanwhile() async throws {
        let editor = FakeTakeEditor()
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        viewModel.player.seek(to: 4)
        var changed: TakeEdit?
        editor.whileFreezing = {
            var timeline = viewModel.edit.timeline
            timeline.split(atEdited: 7)
            viewModel.commit(timeline)
            changed = viewModel.edit
        }
        await viewModel.freezeFrame()
        let after = try #require(changed)
        #expect(editor.stillClips.count == 1)
        #expect(viewModel.edit == after)
        #expect(viewModel.edit.timeline.segments.count == 2)
        #expect(viewModel.edit.sources.isEmpty)
        #expect(!viewModel.isImportingMedia)
        #expect(viewModel.toast.message == "The video changed meanwhile · Freeze the frame again")
        // Only the creator's own split is undone.
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 1)
    }

    @Test func aFrameThatCantBeReadChangesNothing() async {
        let editor = FakeTakeEditor()
        editor.stillClipFails = true
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        let before = viewModel.edit
        await viewModel.freezeFrame()
        #expect(viewModel.edit == before)
    }
}

/// What the editor audit found (2026-10-16), each kept fixed: freeze frame keeps the background and lands where the playhead
/// is, templates leave texts where they were, a tag's word never titles the cover, "Use on every cut" copies the length, Edit by
/// text cuts only the clip the words were read in, and sound effects follow the moment they were put on.
@MainActor
@Suite("Quick edit · audit fixes")
struct QuickEditAuditFixTests {
    private static let said = ["So", "today", "I", "want", "to", "show", "you", "three", "habits"]

    private func makeViewModel(duration: TimeInterval = 30, editor: FakeTakeEditor = FakeTakeEditor()) async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = duration
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        editor.duration = duration
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    @Test func aFrozenFrameKeepsTheBackgroundAndLandsBeforeAClipItOpens() async throws {
        let (viewModel, player) = await makeViewModel()
        var blur = BackgroundEffect()
        blur.style = .blur
        viewModel.change { $0.backgrounds = [RecordingBackground(sourceID: nil, effect: blur)] }
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 10)
        viewModel.commit(timeline)
        let second = viewModel.edit.timeline.segments[1].id
        // Just after the cut: too close to split, so the frame goes before the clip it opens.
        player.seek(to: 10.03)
        await viewModel.freezeFrame()
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 3)
        #expect(segments[1].sourceID == viewModel.edit.sources.first?.id)
        #expect(segments[2].id == second)
        #expect(viewModel.edit.background(for: segments[1])?.style == .blur)
    }

    @Test func aTemplateLeavesTextsWhereTheCreatorPutThem() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.addText(.callout)
        let id = try #require(viewModel.edit.texts.first?.id)
        viewModel.change { snapshot in
            if let index = snapshot.texts.firstIndex(where: { $0.id == id }) {
                snapshot.texts[index].center = OverlayPoint(x: 0.8, y: 0.3)
                snapshot.texts[index].customized.insert(.position)
            }
        }
        viewModel.applyVideoTemplate(.story)
        let text = try #require(viewModel.edit.texts.first { $0.id == id })
        #expect(text.center == OverlayPoint(x: 0.8, y: 0.3))
        #expect(text.preset == .editorial)
    }

    @Test func aTagsWordNeverTitlesTheCover() async {
        let (viewModel, _) = await makeViewModel()
        viewModel.addGraphic(.tag)
        #expect(!viewModel.coverSuggestions.contains("NEW"))
    }

    @Test func everyCutGetsTheTransitionAndItsLength() async throws {
        let (viewModel, _) = await makeViewModel()
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 20)
        viewModel.commit(timeline)
        viewModel.selectedJoinID = viewModel.edit.timeline.segments[1].id
        viewModel.setTransition(.zoom)
        viewModel.setTransitionDuration(1.2)
        viewModel.setTransitionOnEveryCut(.zoom)
        #expect(viewModel.edit.timeline.segments.dropFirst().allSatisfy { $0.transitionIn == .zoom && $0.transitionDuration == 1.2 })
        let steps = viewModel.history.past.count
        viewModel.setTransitionOnEveryCut(.zoom)
        #expect(viewModel.history.past.count == steps)
    }

    @Test func editByTextCutsOnlyTheClipTheWordsWereReadIn() async throws {
        let (viewModel, _) = await makeViewModel(duration: 10)
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        viewModel.edit.captionTranscript = CaptionTranscript(words: words, languageCode: "en")
        viewModel.change { $0.captions = [CaptionCue(words: words)] }
        viewModel.duplicateSection(viewModel.edit.timeline.segments[0].id)
        #expect(abs(viewModel.edit.editedDuration - 20) < 0.000_1)
        viewModel.tapTranscriptWord(at: 2)
        viewModel.tapTranscriptWord(at: 4)
        viewModel.cutSelectedWords()
        // "I want to" (1.5 s) leaves the first clip; its copy keeps them.
        #expect(abs(viewModel.edit.editedDuration - 18.5) < 0.000_1)
        viewModel.undo()
        #expect(viewModel.transcriptSelection == nil)
    }

    /// A trim drag that goes out past an effect's moment and back leaves the effect exactly where it was: every step of the drag
    /// maps it from the edit before the drag, not from the step before.
    @Test func aSoundEffectComesBackToItsPlaceAfterATrimGoesPastItAndBack() async throws {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 20)
        viewModel.addSoundEffect(.ding)
        let effect = try #require(viewModel.edit.music.first { $0.effect == .ding })
        let clip = viewModel.edit.timeline.segments[0].id
        viewModel.beginTimelineHandle(.clip(clip, .end), snapTimes: [])
        viewModel.moveTimelineHandle(by: -15)
        #expect(abs(viewModel.edit.editedDuration - 15) < 0.000_1)
        viewModel.moveTimelineHandle(by: -4)
        viewModel.moveTimelineHandle(by: 0)
        viewModel.endTimelineHandle()
        #expect(abs(viewModel.edit.editedDuration - 30) < 0.000_1)
        let now = try #require(viewModel.edit.music.first { $0.id == effect.id })
        #expect(abs(now.start - effect.start) < 0.000_1)
    }

    @Test func picksInTheTranscriptGoWhenTheCutsChange() async throws {
        let (viewModel, _) = await makeViewModel(duration: 10)
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        viewModel.edit.captionTranscript = CaptionTranscript(words: words, languageCode: "en")
        viewModel.change { $0.captions = [CaptionCue(words: words)] }
        viewModel.tapTranscriptWord(at: 2)
        viewModel.tapTranscriptWord(at: 4)
        #expect(viewModel.transcriptSelection != nil)
        // A change that leaves the cuts alone keeps the pick.
        viewModel.addText(.title)
        #expect(viewModel.transcriptSelection != nil)
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 6)
        viewModel.commit(timeline)
        #expect(viewModel.transcriptSelection == nil)
    }

    /// A handle held on something that isn't there leaves no change open: the next change is an undo step of its own.
    @Test func aHandleOnNothingLeavesNoChangeOpen() async throws {
        let (viewModel, _) = await makeViewModel()
        let steps = viewModel.history.past.count
        viewModel.beginTimelineHandle(.clip(UUID(), .end), snapTimes: [])
        viewModel.beginTimelineHandle(.move(.text, UUID()), snapTimes: [])
        viewModel.beginTimelineHandle(.item(.caption, UUID(), .start), snapTimes: [])
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 10)
        viewModel.commit(timeline)
        #expect(viewModel.history.past.count == steps + 1)
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 1)
    }

    @Test func aSoundEffectFollowsItsMomentThroughACut() async throws {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 20)
        viewModel.addSoundEffect(.ding)
        let effect = try #require(viewModel.edit.music.first { $0.effect == .ding })
        #expect(abs(effect.start - 20) < 0.000_1)
        // Five seconds earlier in the video go: the ding plays five seconds earlier, still on its moment.
        var timeline = viewModel.edit.timeline
        timeline.remove([TimeSpan(start: 5, end: 10)])
        viewModel.commit(timeline)
        #expect(abs((viewModel.edit.music.first { $0.id == effect.id }?.start ?? 0) - 15) < 0.000_1)
    }
}
