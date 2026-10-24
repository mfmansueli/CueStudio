//
//  LookPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The picture as a part of the editor (`LookViewModel`), with only a host around it: a dial changes the take or, opened from
/// a clip, only that clip, each an undo step of the session's document; Compare asks the editor to show the preview again and
/// ends when the edit changes or the panel closes; a clip's scope ends with the panels.
@MainActor
@Suite("Look part")
struct LookPartTests {
    let host: FakeEditorHost
    let part: LookViewModel

    init() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        var timeline = edit.timeline
        _ = timeline.split(atEdited: 10)
        edit.timeline = timeline
        host = FakeEditorHost(edit: edit)
        part = LookViewModel(session: host.session, editing: FakeTakeEditor(), motion: nil)
    }

    @Test func aDialChangesTheTakeOrOnlyThePickedClip() throws {
        part.setAdjustment(.exposure, 30)
        #expect(host.document.edit.exposure == 30)
        let clip = try #require(host.document.edit.timeline.segments.last)
        host.selection = .clip(clip.id)
        part.lookScopeIsClip = true
        part.setAdjustment(.exposure, -20)
        #expect(host.document.edit.exposure == 30)
        #expect(host.document.edit.timeline.segment(id: clip.id)?.look?.exposure == -20)
        #expect(part.adjustment(.exposure) == -20)
        host.undo()
        #expect(host.document.edit.timeline.segment(id: clip.id)?.look == nil)
    }

    @Test func compareShowsThePreviewAgainAndEndsWithAChange() {
        part.setAdjustment(.contrast, 40)
        let shown = host.playedEditShown
        part.togglePictureComparison()
        #expect(part.comparesPicture)
        #expect(host.playedEditShown == shown + 1)
        part.editChanged()
        #expect(!part.comparesPicture)
        #expect(host.playedEditShown == shown + 2)
    }

    @Test func aClipsScopeFollowsThePickedClipAndEndsWithThePanels() throws {
        let clip = try #require(host.document.edit.timeline.segments.first)
        part.lookScopeIsClip = true
        #expect(part.followsSelection(.adjust))
        #expect(part.accepts(.clip(clip.id), in: .adjust))
        #expect(!part.accepts(.text(UUID()), in: .adjust))
        part.panelChanged(to: .filters)
        #expect(part.lookScopeIsClip)
        part.panelChanged(to: nil)
        #expect(!part.lookScopeIsClip)
        #expect(!part.followsSelection(.adjust))
    }
}
