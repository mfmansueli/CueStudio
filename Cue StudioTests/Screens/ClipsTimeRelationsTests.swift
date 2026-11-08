//
//  ClipsTimeRelationsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The video track's changes and what goes with them (plan §6, matrix §4), with only a host around the part: deleting a clip
/// says what went with it and Undo brings it all back, duplicating a split's right part copies what is on it, and moving the
/// music along after an insert is one step of its own.
@MainActor
@Suite("Clips time relations")
struct ClipsTimeRelationsTests {
    private static func part(for edit: TakeEdit) -> (FakeEditorHost, ClipsViewModel) {
        let host = FakeEditorHost(edit: edit)
        let part = ClipsViewModel(
            session: host.session, editing: FakeTakeEditor(), takes: TakeLibraryService(repository: FakeTakeRepository(takes: [])),
            library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), speechLanguage: { _ in .language(.english) }
        )
        return (host, part)
    }

    private static func effect(at start: TimeInterval) -> MusicClip {
        var clip = MusicClip(fileName: "ding.m4a", title: "Ding", fileDuration: 1, start: start, length: 1)
        clip.effect = .ding
        return clip
    }

    /// Matrix §4, "Aviso de remoção": the toast says what went with the clip, with Undo, and Undo brings it back.
    @Test func deletingAClipSaysWhatWentWithItAndUndoBringsItBack() throws {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.timeline.split(atEdited: 4)
        edit.timeline.split(atEdited: 8)
        edit.texts = [TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 5, end: 7))]
        edit.music = [Self.effect(at: 5), Self.effect(at: 6.5)]
        let (host, part) = Self.part(for: edit)
        part.deleteClip(edit.timeline.segments[1].id)
        let message = try #require(host.session.toast.message)
        #expect(message.hasPrefix("Clip 2 deleted, with"), "\(message)")
        #expect(message.contains("1 text") && message.contains("2 sounds"), "\(message)")
        #expect(host.session.toast.action?.title == String(localized: "Undo"))
        #expect(host.document.edit.music.isEmpty)
        host.undo()
        #expect(host.document.edit.timeline == edit.timeline && host.document.edit.music == edit.music && host.document.edit.texts == edit.texts)
    }

    /// Nothing went with it: the toast is as it was.
    @Test func deletingAnEmptyClipSaysOnlyThat() {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.timeline.split(atEdited: 4)
        let (host, part) = Self.part(for: edit)
        part.deleteClip(edit.timeline.segments[1].id)
        #expect(host.session.toast.message == String(localized: "Clip 2 deleted"))
    }

    /// Matrix §4, "Reverter ou duplicar depois de dividir": duplicating a split's right part copies the text on it (it still
    /// names the left part), and the left part's copy gets nothing of it.
    @Test func duplicatingASplitsRightPartCopiesWhatIsOnIt() throws {
        var edit = TakeEdit(sourceDuration: 12, aspect: .portrait)
        edit.timeline.insertClip(source: UUID(), duration: 4)
        var text = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 0, end: 1))
        let pinned = edit.pin(TimeSpan(start: 2.5, end: 3.5))
        text.clipAnchor = pinned.anchor
        text.span = pinned.span
        edit.texts = [text]
        edit.timeline.split(atEdited: 2)
        let (host, part) = Self.part(for: edit)
        let left = edit.timeline.segments[0].id, right = edit.timeline.segments[1].id
        part.duplicateClip(left)
        #expect(host.document.edit.texts.count == 1, "nothing of the left part's is on it")
        host.undo()
        part.duplicateClip(right)
        let texts = host.document.edit.texts
        #expect(texts.count == 2)
        let timeline = host.document.edit.timeline
        let spans = texts.compactMap { TakeEdit.editedSpan($0.span, anchor: $0.clipAnchor, in: timeline) }.sorted { $0.start < $1.start }
        // The right part plays 2–12 s of the edit, its copy right after it, from 12 s.
        #expect(spans.count == 2)
        #expect(abs(spans[0].start - 2.5) < 0.01 && abs(spans[1].start - 12.5) < 0.01)
    }

    /// Matrix §4, "Música sob introdução inserida": Move music along is one undo step; after another change it says so.
    @Test func movingTheMusicAlongIsOneStep() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.music = [MusicClip(fileName: "m.m4a", title: "Loop", fileDuration: 60, start: 0, length: 8)]
        edit.timeline.insertClip(source: UUID(), duration: 3, at: 0)
        let (host, part) = Self.part(for: edit)
        let steps = host.document.history.past.count
        part.moveMusicAlong(from: 0, by: 3, ifStill: edit.timeline)
        #expect(host.document.edit.music[0].start == 3)
        #expect(host.document.history.past.count == steps + 1)
        host.undo()
        #expect(host.document.edit.music[0].start == 0)
        part.moveMusicAlong(from: 0, by: 3, ifStill: EditTimeline(sourceDuration: 10))
        #expect(host.document.edit.music[0].start == 0)
        #expect(host.session.toast.kind == .problem)
    }
}
