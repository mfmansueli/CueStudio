//
//  QuickEditViewModel+Cover.swift
//  Cue Studio
//

import Foundation

/// Cover: made in Cover Studio, which opens over the editor (the toolbar's Cover, the cover block on the timeline, a
/// notification's "Try it"). The studio works on its own copy with its own undo; Done puts the cover in the edit as one undo
/// step here, Cancel leaves it as it was. The cover is drawn on the device for the timeline's cover block and saved to Photos
/// with each export, ready to pick as the post's cover.
extension QuickEditViewModel {
    // MARK: - Cover Studio

    /// Opens Cover Studio on the cover, or on a new one from the frame under the playhead.
    func openCoverStudio() {
        guard isReady else { return }
        player.pause()
        selection = nil
        toolMenu = nil
        panel = nil
        coverStudio = CoverStudioViewModel(
            cover: edit.cover, frame: edit.coverFrame(atEdited: player.currentTime), edit: edit, videoURL: videoURL,
            handle: creatorHandle, suggestions: coverSuggestions, pictures: coverPictures, importer: mediaImporter, styles: styles
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

    // MARK: - Quick changes

    /// The frame under the playhead becomes the cover's picture (a new cover in the saved style when there's none).
    func useFrameAsCover() {
        guard isReady else { return }
        let frame = edit.coverFrame(atEdited: player.currentTime)
        let handle = creatorHandle
        let style = styles.myCoverStyle
        change { snapshot in
            if snapshot.cover == nil {
                var cover = VideoCover(source: .clipFrame(frame), style: snapshot.creatorStyle ?? .bold)
                cover.composition = style?.composition(title: "", handle: handle, episode: 1) ?? CoverComposition.make(.educational, title: "")
                snapshot.cover = cover
            } else {
                snapshot.cover?.source = .clipFrame(frame)
            }
        }
        player.pause()
        toast.show(String(localized: "Cover set to this frame"))
    }

    /// The words on the cover; a cover is made from the playhead's frame when there's none yet. Typing in a row is one undo
    /// step.
    func setCoverTitle(_ title: String) {
        if edit.cover == nil { useFrameAsCover() }
        change(key: "coverTitle") { $0.cover?.title = title }
    }

    /// Where the title sits, as a share of the cover's height from the top.
    func setCoverTitlePosition(_ y: Double) {
        guard edit.cover != nil else { return }
        let clamped = min(max(y, OverlayPoint.margin), 1 - OverlayPoint.margin)
        change { snapshot in
            snapshot.cover?.titleY = clamped
            snapshot.cover?.composition?.title.center.y = clamped
        }
    }

    func removeCover() {
        change { $0.cover = nil }
        coverImage = nil
    }

    /// The cover's frame is from a part removed from the edit: it stays the cover (from its recording).
    var coverFrameLeftTheEdit: Bool { edit.coverFrameLeftTheEdit }

    /// Titles Cue can offer from the take's own words: a text on the video, the script's title and its first sentence, short
    /// enough for a cover.
    var coverSuggestions: [String] {
        let sentence = captionScript.flatMap { script in
            script.text.split(whereSeparator: { ".!?\n".contains($0) }).first.map { $0.trimmingCharacters(in: .whitespaces) }
        }
        var seen = Set<String>()
        return [edit.texts.first { $0.graphic == nil }?.text, take.scriptTitle, sentence]
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
        coverTask?.cancel()
        guard let cover = edit.cover else {
            coverImage = nil
            drawnCoverKey = nil
            isDrawingCover = false
            return
        }
        isDrawingCover = true
        let current = self.edit
        coverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled else { return }
            let image = await self.editing.coverImage(cover, forVideoAt: self.videoURL, edit: current)
            guard !Task.isCancelled else { return }
            self.coverImage = image
            self.drawnCoverKey = key
            self.isDrawingCover = false
        }
    }
}
