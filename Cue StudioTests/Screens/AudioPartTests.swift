//
//  AudioPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The sound as a part of the editor (`AudioViewModel`), with only a host around it: a narration recorded over the edit is
/// added as one undo step of the session's document when it stops (asked, or on its own), leaving Studio Voice ends its
/// comparison and shows the preview again, and "Replace" asks for a file only in the sheet it opened.
@MainActor
@Suite("Audio part")
struct AudioPartTests {
    let host: FakeEditorHost
    let recorder: FakeVoiceRecorder
    let part: AudioViewModel

    init() {
        host = FakeEditorHost(edit: TakeEdit(sourceDuration: 20, aspect: .portrait))
        recorder = FakeVoiceRecorder()
        part = AudioViewModel(
            session: host.session, editing: FakeTakeEditor(), importer: FakeMediaImporter(), recorder: recorder,
            editorPreferences: FakeEditorPreferencesStore(), prompterLook: PrompterSettings(), soundPreviews: SoundEffectPreviewPlayer()
        )
    }

    @Test func aNarrationStoppedIsAddedAsOneUndoStep() async {
        host.session.player.seek(to: 3)
        await part.startVoiceOver()
        #expect(part.isRecordingVoiceOver)
        #expect(part.recordingStart == 3)
        part.stopRecordingIfNeeded()
        #expect(!part.isRecordingVoiceOver)
        #expect(host.document.edit.voiceOvers.count == 1)
        #expect(host.selection == .voiceOver(host.document.edit.voiceOvers[0].id))
        #expect(host.document.history.past.count == 1)
    }

    @Test func aNarrationTheMicrophoneLostIsKept() async {
        await part.startVoiceOver()
        recorder.stopOnItsOwn(.interrupted)
        #expect(host.document.edit.voiceOvers.count == 1)
    }

    @Test func leavingStudioVoiceEndsItsComparison() {
        part.comparesOriginal = true
        part.originalVolume = 0.8
        let shown = host.playedEditShown
        part.panelChanged(from: .voice)
        #expect(!part.comparesOriginal)
        #expect(part.originalVolume == nil)
        #expect(host.playedEditShown == shown + 1)
    }

    @Test func replaceAsksOnlyInTheSheetItOpened() {
        part.musicReplacementID = UUID()
        part.sheetChanged(to: .music)
        #expect(part.musicReplacementID != nil)
        part.sheetChanged(to: nil)
        #expect(part.musicReplacementID == nil)
    }
}
