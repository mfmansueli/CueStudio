//
//  EditorSession.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// What every part of the editor (`EditorPart`: Captions, …) works through: the edit and its undo steps, the player, the jobs
/// and the toasts, held by the part itself, and what is picked, the open panel and Undo, asked of the editor (`EditorHost`).
/// A part changes the edit only through the document and never reaches another part: what one part's change means for
/// another (a panel left, an edit changed, the editor closed) is the editor's to wire.
///
/// The editor is held weakly: it owns its parts, and a part's job that finishes after the editor has gone still finds its
/// document, jobs and player (closed, so its result is dropped) and nothing to pick.
@MainActor
@Observable
final class EditorSession {
    /// The edit and its undo steps: the one way the edit changes.
    let document: EditDocument
    let player: EditPlayback
    /// Everything started and waited for; closing the editor cancels it all.
    let jobs: EditorJobs
    let toast: ToastService
    /// The take being edited.
    let take: Take
    /// The take's recording.
    let videoURL: URL
    @ObservationIgnored weak var host: (any EditorHost)?
    /// Media files copied in while the editor is open, so what the edit doesn't keep is removed when it closes.
    @ObservationIgnored var importedFiles: Set<String> = []
    /// A file is being brought in or written (a photo or video, a clip replaced or reversed, a sound pulled out): one at a time.
    var isImportingMedia = false
    /// A reverse or an import the creator waits for, over the preview with how far it is and Cancel.
    var work: EditorWork?
    /// Frames per second of the recording: read from the file when it opens, the take's setting until then.
    var frameRate: Double
    /// Copies a picked photo or video into the edit's media.
    let importer: EditMediaImporting
    /// The creator's handle, for the "@handle" graphic and the cover's series (set by the screen).
    var creatorHandle = ""

    init(
        document: EditDocument, player: EditPlayback, jobs: EditorJobs, toast: ToastService, take: Take, videoURL: URL,
        importer: EditMediaImporting
    ) {
        self.document = document
        self.importer = importer
        frameRate = Double(take.frameRate.rawValue)
        self.player = player
        self.jobs = jobs
        self.toast = toast
        self.take = take
        self.videoURL = videoURL
    }

    /// The recording is open and the preview can play.
    var isReady: Bool { host?.isReady ?? false }

    /// The one thing picked.
    var selection: EditorSelection? {
        get { host?.selection }
        set { host?.selection = newValue }
    }

    /// The panel under the timeline.
    var panel: EditorPanel? {
        get { host?.panel }
        set { host?.panel = newValue }
    }

    /// The open panel's tab.
    var panelTab: EditorPanelTab {
        get { host?.panelTab ?? .presets }
        set { host?.panelTab = newValue }
    }

    /// The Text or Audio toolbar.
    var toolMenu: EditorToolMenu? {
        get { host?.toolMenu }
        set { host?.toolMenu = newValue }
    }

    /// The sheet over the editor.
    var sheet: EditorSheet? {
        get { host?.sheet }
        set { host?.sheet = newValue }
    }

    /// The take's script as captions and Clean Up read it (a matching version only); nil for a freestyle take.
    var captionScript: Script? { host?.captionScript }

    func undo() {
        host?.undo()
    }

    /// Writes down a failure the creator was told about (`EditorFailureReport`).
    func noteFailure(_ error: any Error, _ operation: String) {
        host?.noteFailure(error, operation)
    }

    /// What the preview plays changed: the player shows it again.
    func showPlayedEdit() {
        host?.showPlayedEdit()
    }

    // MARK: - Work the creator waits for

    /// The picked photo or video copied in (from iCloud first when it isn't on the iPhone), with how far it got said over the
    /// preview; Cancel (or leaving) stops it with `CancellationError`, and a copy that lands as Cancel comes goes.
    func importPicked(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        let job = EditorJobs.Kind.importing(UUID())
        work = EditorWork(kind: .importing, job: job)
        defer { if work?.job == job { work = nil } }
        return try await jobs.run(
            job,
            discard: { EditMediaFiles.remove([$0.fileName]) },
            work: { [weak self, importer] in try await importer.importMedia(item) { fraction in self?.reportWork(job, fraction) } }
        )
    }

    /// How far the work run as `job` is, unless it was cancelled meanwhile.
    func reportWork(_ job: EditorJobs.Kind, _ fraction: Double) {
        guard work?.job == job else { return }
        work?.fraction = min(max(fraction, 0), 1)
    }

    /// Cancel, on the pill: the work stops and the edit stays as it was.
    func cancelWork() {
        guard let work else { return }
        jobs.cancel(work.job)
        self.work = nil
    }

    /// Undo, as the toast's button.
    var undoAction: ToastAction {
        ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
    }

    /// The toast for a change that can be taken back.
    func sayUndoable(_ message: String) {
        toast.show(message, action: undoAction)
    }

    /// Plays `range` (edited seconds) once, then puts the playhead back where it was (or at `back`).
    func previewPart(_ range: ClosedRange<TimeInterval>, back: TimeInterval? = nil) {
        let back = back ?? player.currentTime
        jobs.cancel(.preview)
        player.pause()
        player.reviewedPart = range
        player.seek(to: range.lowerBound)
        player.play()
        jobs.start(.preview) { [player] _ in
            try? await Task.sleep(for: .seconds(range.upperBound - range.lowerBound + 0.3))
            guard !Task.isCancelled else { return }
            if player.reviewedPart == range { player.reviewedPart = nil }
            player.pause()
            player.seek(to: back)
        }
    }
}
