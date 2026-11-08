//
//  TakeReviewViewModel+Cover.swift
//  Cue Studio
//

import Foundation

/// The chosen cover, saved to Photos after its video, and Try again when it couldn't be.
extension TakeReviewViewModel {
    /// The chosen cover, saved to Photos after its video: true when one was. One that couldn't be saved says so, the video being there, with
    /// **Try again**, which saves the cover alone (`retryCover`).
    @discardableResult
    func saveCover(after operation: ExportOperation) async -> Bool {
        do {
            let saved = try await saveCoverIfChosen()
            if saved { coversSaved.insert(operation.id) }
            return saved
        } catch {
            if !(error is PhotoLibraryError), let failure = EditorFailureReport.make(error, operation: "cover", edit: take?.edit) {
                reportFailure(failure)
            }
            offerCoverAgain(for: operation.id)
            return false
        }
    }

    private func offerCoverAgain(for operationID: UUID) {
        toast.showResult(
            String(localized: "Video saved. Couldn't save the cover image."), kind: .problem,
            action: ToastAction(title: String(localized: "Try again")) { [weak self] in self?.retryCover(for: operationID) }
        )
    }

    /// The cover alone, drawn and saved again: no new video, nothing counted.
    func retryCover(for operationID: UUID) {
        coverRetry?.cancel()
        coverRetry = Task {
            do {
                guard try await saveCoverIfChosen() else { return }
                coversSaved.insert(operationID)
                toast.show(String(localized: "Cover saved to Photos"))
            } catch {
                offerCoverAgain(for: operationID)
            }
        }
    }

    /// Draws the take's cover and saves it to Photos. False when no cover was chosen.
    private func saveCoverIfChosen() async throws -> Bool {
        guard let take, let edit = take.edit, let cover = edit.cover else { return false }
        guard let data = await editing.coverImage(cover, forVideoAt: takes.videoURL(for: take), edit: edit) else {
            throw CoverError.unreadable
        }
        let url = URL.temporaryDirectory.appending(path: "Cue-cover-\(UUID().uuidString.prefix(8)).jpg")
        try data.write(to: url, options: .atomic)
        // Photos keeps its own copy.
        defer { try? FileManager.default.removeItem(at: url) }
        try await photos.saveImage(at: url)
        return true
    }
}
