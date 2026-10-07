//
//  QuickEditViewModel+Montage.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// Montage: copying a section, putting sections in another order, and adding other takes or
/// videos as sections of their own. The first time the edit is arranged, its texts, media and
/// voice-overs are pinned to the section they play on, so they travel with it; a copied section
/// gets copies of its own (new identities). Removing a section never touches the take or the video
/// it came from. Each change is one undo step.
extension QuickEditViewModel {
    /// A section of the edit as the Clips sheet lists it.
    struct Clip: Identifiable, Equatable {
        let id: UUID
        let index: Int
        /// "This take", or the other take's or video's name.
        let title: String
        /// Edited seconds.
        let duration: TimeInterval
        let sourceID: UUID?
        /// Seconds of its recording shown on its thumbnail.
        let thumbnailTime: TimeInterval
    }

    /// Every section, in play order.
    var clips: [Clip] {
        let timeline = edit.timeline
        return timeline.segments.enumerated().map { index, segment in
            Clip(
                id: segment.id, index: index, title: title(ofSource: segment.sourceID), duration: segment.duration,
                sourceID: segment.sourceID, thumbnailTime: (segment.sourceStart + segment.sourceEnd) / 2
            )
        }
    }

    /// The montage's other recordings' files, by source.
    var clipSourceURLs: [UUID: URL] {
        Dictionary(edit.sources.map { ($0.id, EditMediaFiles.url(for: $0.fileName)) }) { first, _ in first }
    }

    // MARK: - Arranging

    /// Copies the picked section (or the one under the playhead) right after it, with what plays on
    /// it.
    func duplicateSection() {
        guard isReady else { return }
        let timeline = edit.timeline
        let index = selectedSegmentIndex ?? timeline.segmentIndex(atEdited: player.currentTime)
        duplicateSection(timeline.segments[index].id)
    }

    func duplicateSection(_ id: UUID) {
        guard isReady else { return }
        var next = arranged(edit)
        guard let copyID = next.timeline.duplicateSegment(id: id) else { return }
        next.texts += next.texts.filter { $0.clipAnchor?.segmentID == id }.map { text in
            var copy = text
            copy.id = UUID()
            copy.clipAnchor?.segmentID = copyID
            return copy
        }
        next.media += next.media.filter { $0.clipAnchor?.segmentID == id }.map { item in
            var copy = item
            copy.id = UUID()
            copy.clipAnchor?.segmentID = copyID
            return copy
        }
        next.voiceOvers += next.voiceOvers.filter { $0.clipAnchor?.segmentID == id }.map { clip in
            var copy = clip
            copy.id = UUID()
            copy.clipAnchor?.segmentID = copyID
            return copy
        }
        commit(EditSnapshot(next))
        toast.show(String(localized: "Section copied"))
    }

    /// Moves the section at `source` so it plays at `destination`.
    func moveSection(from source: Int, to destination: Int) {
        guard isReady else { return }
        var next = arranged(edit)
        guard next.timeline.moveSegment(from: source, to: destination) else { return }
        commit(EditSnapshot(next))
    }

    /// Takes a section out of the edit (never the recording it comes from).
    func removeSection(_ id: UUID) {
        guard isReady else { return }
        var timeline = edit.timeline
        guard timeline.removeSegment(id: id) else {
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        commit(timeline)
    }

    // MARK: - Adding

    /// Adds another take from the library at the end of the montage (or after the picked section).
    func addClip(from take: Take) async {
        guard isReady else { return }
        let file = takes.videoURL(for: take)
        do {
            let duration = try await editing.sourceDuration(ofVideoAt: file)
            let name = try EditMediaFiles.link(file)
            importedFiles.insert(name)
            let title = String(localized: "\(take.scriptTitle) · Take \(take.number)")
            var source = ClipSource(fileName: name, duration: duration, title: title, takeID: take.id)
            source.scriptReference = take.captionScript(current: library.script(id: take.scriptID))
            addSource(source)
        } catch {
            toast.show(String(localized: "Can't add this take"))
        }
    }

    /// Adds a video from Photos at the end of the montage (or after the picked section).
    func addClip(importing item: PhotosPickerItem) async {
        guard isReady else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            let imported = try await mediaImporter.importMedia(item)
            importedFiles.insert(imported.fileName)
            guard imported.kind == .video, let duration = imported.duration else {
                toast.show(String(localized: "Pick a video first"))
                return
            }
            addSource(ClipSource(fileName: imported.fileName, duration: duration, title: String(localized: "Video")))
        } catch {
            toast.show(String(localized: "Can't add this file"))
        }
    }

    private func addSource(_ source: ClipSource) {
        var next = arranged(edit)
        let at = selectedSegmentIndex.map { $0 + 1 }
        guard let id = next.timeline.insertClip(source: source.id, duration: source.duration, at: at) else {
            toast.show(String(localized: "Video too short to add"))
            return
        }
        next.sources.append(source)
        commit(EditSnapshot(next))
        player.seek(to: next.timeline.editedStart(ofSegmentAt: next.timeline.index(ofSegment: id) ?? 0))
        toast.show(String(localized: "\(source.title) added"))
    }

    // MARK: - Private

    /// `edit` ready to be arranged: pinned to its sections the first time.
    private func arranged(_ edit: TakeEdit) -> TakeEdit {
        var next = edit
        if !next.timeline.isArranged { next.anchorOverlays() }
        return next
    }

    private func title(ofSource id: UUID?) -> String {
        guard let id else { return String(localized: "This take") }
        return edit.sources.first { $0.id == id }?.title ?? String(localized: "Video")
    }
}
