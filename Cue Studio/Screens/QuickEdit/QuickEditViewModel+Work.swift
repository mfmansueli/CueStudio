//
//  QuickEditViewModel+Work.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// Work the creator waits for, over the preview with how far it is and Cancel (`EditorWork`): a reverse, and a photo or video
/// brought in from the library (from iCloud first when it isn't on the iPhone, which can take a while). Cancel leaves the
/// edit as it was.
extension QuickEditViewModel {
    /// The picked photo or video copied in, with how far it got said over the preview; Cancel (or leaving) stops it with
    /// `CancellationError`.
    func importPicked(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        let job = EditorJobs.Kind.importing(UUID())
        work = EditorWork(kind: .importing, job: job)
        defer { if work?.job == job { work = nil } }
        let importer = mediaImporter
        // Brought in as Cancel came: the copy goes.
        return try await jobs.run(
            job,
            discard: { EditMediaFiles.remove([$0.fileName]) },
            work: { [weak self] in try await importer.importMedia(item) { fraction in self?.reportWork(job, fraction) } }
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
}
