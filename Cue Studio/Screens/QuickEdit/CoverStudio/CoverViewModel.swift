//
//  CoverViewModel.swift
//  Cue Studio
//

import Foundation

/// Cover: made in Cover Studio, which opens over the editor (the toolbar's Cover, the cover block on the timeline, a
/// notification's "Try it"). The studio works on its own copy with its own undo; Done puts the cover in the edit as one undo
/// step here, Cancel leaves it as it was. The cover is drawn on the device for the timeline's cover block and saved to Photos
/// with each export, ready to pick as the post's cover. A part of the editor (`EditorPart`).
@MainActor
@Observable
final class CoverViewModel: EditorPart {
    /// The cover as drawn, for the timeline's cover block; nil until drawn or without a cover.
    var coverImage: Data?
    var isDrawingCover = false
    /// Cover Studio, while it's open over the editor.
    var coverStudio: CoverStudioViewModel?
    /// `TakeEdit.coverDrawingKey` of the cover block's drawing.
    @ObservationIgnored var drawnCoverKey: Int?

    let session: EditorSession
    let editing: TakeEditing
    /// Cover Studio's pictures.
    let pictures: CoverPicturing
    /// Copies a photo Cover Studio picks into the edit's media.
    let importer: EditMediaImporting
    let styles: TextStyleStoring

    init(session: EditorSession, editing: TakeEditing, pictures: CoverPicturing, importer: EditMediaImporting, styles: TextStyleStoring) {
        self.session = session
        self.editing = editing
        self.pictures = pictures
        self.importer = importer
        self.styles = styles
    }

    /// The edit changed: the cover block is drawn again when what it shows changed.
    func editChanged() {
        if edit.coverDrawingKey != drawnCoverKey { drawCover() }
    }

    // MARK: - Cover Studio

    /// Opens Cover Studio on the cover, or on a new one from the frame under the playhead.
    func openCoverStudio() {
        guard isReady else { return }
        player.pause()
        selection = nil
        toolMenu = nil
        panel = nil
        coverStudio = CoverStudioViewModel(
            cover: edit.cover, frame: edit.coverFrame(atEdited: player.currentTime), edit: edit, videoURL: session.videoURL,
            handle: session.creatorHandle, suggestions: coverSuggestions, pictures: pictures, importer: importer, styles: styles
        )
    }

    /// Done: the studio's cover goes in the edit (one undo step), and the photos it copied in are kept with the edit.
    func finishCoverStudio(_ studio: CoverStudioViewModel) {
        importedFiles.formUnion(studio.importedFiles)
        let cover = studio.finishedCover
        let changed = cover != edit.cover
        change { $0.cover = cover }
        coverStudio = nil
        guard changed else { return }
        toast.show(cover == nil ? String(localized: "Cover removed") : String(localized: "Cover saved · Goes to Photos with the video"))
    }

    /// Cancel: the edit keeps its cover; every photo copied in this time goes, unless the edit already reads it.
    func cancelCoverStudio(_ studio: CoverStudioViewModel) {
        EditMediaFiles.remove(studio.importedFiles.subtracting(edit.mediaFileNames))
        coverStudio = nil
    }

    // MARK: - Suggestions

    /// Titles Cue can offer from the take's own words: a text on the video, the script's title and its first sentence, short
    /// enough for a cover.
    var coverSuggestions: [String] {
        let sentence = session.captionScript.flatMap { script in
            script.text.split(whereSeparator: { ".!?\n".contains($0) }).first.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var seen = Set<String>()
        return [edit.texts.first { $0.graphic == nil }?.text, session.take.scriptTitle, sentence]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 60 && seen.insert($0.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Drawing

    /// Draws the cover for the timeline's cover block, a moment after it changed.
    func drawCover() {
        let key = edit.coverDrawingKey
        guard drawnCoverKey != key || coverImage == nil else { return }
        jobs.cancel(.cover)
        guard let cover = edit.cover else {
            coverImage = nil
            drawnCoverKey = nil
            isDrawingCover = false
            return
        }
        isDrawingCover = true
        let current = self.edit
        jobs.start(.cover) { [weak self] ticket in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, jobs.isCurrent(ticket), !Task.isCancelled else { return }
            let image = await self.editing.coverImage(cover, forVideoAt: self.session.videoURL, edit: current)
            guard jobs.isCurrent(ticket) else { return }
            self.coverImage = image
            self.drawnCoverKey = key
            self.isDrawingCover = false
        }
    }
}
