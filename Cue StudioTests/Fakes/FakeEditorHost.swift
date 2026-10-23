//
//  FakeEditorHost.swift
//  Cue StudioTests
//

import Foundation
import PhotosUI
import SwiftUI
@testable import Cue_Studio

/// An editor that is only a host (`EditorHost`): a part of the editor (`EditorPart`) tested on its own, with what is picked
/// and the panels as plain values, Undo going to the document, failures and the preview shown again counted, and photos
/// brought in through `importer`. Keep it alive for the test: its session
/// holds it weakly, the way the editor is held.
@MainActor
final class FakeEditorHost: EditorHost {
    let session: EditorSession
    var isReady = true
    var selection: EditorSelection?
    var panel: EditorPanel?
    var panelTab: EditorPanelTab = .presets
    var toolMenu: EditorToolMenu?
    var sheet: EditorSheet?
    var captionScript: Script?
    var importer: EditMediaImporting = FakeMediaImporter()
    private(set) var failures: [String] = []
    private(set) var playedEditShown = 0

    init(take: Take = TestData.take(scriptID: nil), edit: TakeEdit? = nil, player: EditPlayback = FakeEditPlayback()) {
        let document = EditDocument(edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect))
        session = EditorSession(
            document: document, player: player, jobs: EditorJobs(), toast: ToastService(), take: take,
            videoURL: URL.temporaryDirectory.appending(path: take.fileName)
        )
        session.host = self
        // Ready, as the editor is once the recording opens: the player shows the edit.
        player.show(document.edit)
    }

    var document: EditDocument { session.document }

    func undo() {
        _ = session.document.undo()
    }

    func noteFailure(_ error: any Error, _ operation: String) {
        failures.append(operation)
    }

    func showPlayedEdit() {
        playedEditShown += 1
    }

    func importPicked(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        try await importer.importMedia(item) { _ in }
    }
}
