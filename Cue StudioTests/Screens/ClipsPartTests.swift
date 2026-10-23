//
//  ClipsPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The video track as a part of the editor (`ClipsViewModel`), with only a host around it: a split at the playhead is one undo
/// step of the session's document and leaves the right part picked through the host, a change of the cuts lets go of the
/// words picked in Edit by text, and a clip's handle held on the timeline steps curved clips' sound.
@MainActor
@Suite("Clips part")
struct ClipsPartTests {
    let host: FakeEditorHost
    let part: ClipsViewModel

    init() {
        host = FakeEditorHost(edit: TakeEdit(sourceDuration: 20, aspect: .portrait))
        part = ClipsViewModel(
            session: host.session, editing: FakeTakeEditor(), takes: TakeLibraryService(repository: FakeTakeRepository(takes: [])),
            library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), speechLanguage: { _ in .language(.english) }
        )
    }

    @Test func aSplitIsOneUndoStepAndPicksTheRightPart() throws {
        let clip = try #require(host.document.edit.timeline.segments.first)
        host.selection = .clip(clip.id)
        host.session.player.seek(to: 8)
        part.splitClip()
        let segments = host.document.edit.timeline.segments
        #expect(segments.count == 2)
        #expect(host.selection == .clip(segments[1].id))
        #expect(host.document.history.past.count == 1)
    }

    @Test func aChangeOfTheCutsLetsGoOfThePickedWords() {
        part.transcriptSelection = 0...2
        let before = host.document.edit
        host.document.changeEdit { $0.showsCaptions.toggle() }
        part.editChanged(from: before)
        #expect(part.transcriptSelection == 0...2)
        let shown = host.document.edit
        var timeline = shown.timeline
        _ = timeline.split(atEdited: 5)
        host.document.commit(timeline)
        part.editChanged(from: shown)
        #expect(part.transcriptSelection == nil)
    }

    @Test func aHeldClipHandleStepsTheCurvedSound() {
        part.holdsClipHandle = true
        part.updateCurveSoundStepping()
        #expect(host.session.player.stepsCurveSound)
        part.holdsClipHandle = false
        part.updateCurveSoundStepping()
        #expect(!host.session.player.stepsCurveSound)
    }
}
