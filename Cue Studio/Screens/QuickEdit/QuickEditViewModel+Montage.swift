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

    /// Copies a section right after it, with what plays on it.
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

    // MARK: - Adding

    /// The creator's other takes, newest first: Add photo or video › Insert as clip offers them before Photos.
    var addableTakes: [Take] {
        takes.takes.filter { $0.id != take.id }
    }

    /// Adds another take from the library at the end of the montage (or after the picked section).
    func addClip(from take: Take) async {
        guard isReady else { return }
        let file = takes.videoURL(for: take)
        do {
            let duration = try await editing.sourceDuration(ofVideoAt: file)
            guard !isClosed else { return }
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
            guard !isClosed else {
                EditMediaFiles.remove([imported.fileName])
                return
            }
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
        sayUndoable(String(localized: "\(source.title) added"))
    }

    /// Reorder: the clips in a list to drag, from the clip's tools or holding a clip on the timeline. One clip: nothing to order.
    func openClipOrder() {
        guard isReady else { return }
        guard edit.timeline.segments.count > 1 else {
            toast.show(String(localized: "Split or add a clip to reorder"))
            return
        }
        player.pause()
        sheet = .clipOrder
    }

    // MARK: - Freeze frame

    /// How long a freeze frame holds at first; its file is longer, so its end handle can stretch it.
    static let freezeLength: TimeInterval = 2
    static let freezeFileLength: TimeInterval = 5

    /// Holds the frame under the playhead: the clip is split there and the frame plays as a clip of its own, silent, with the
    /// look of the clip it came from (the music and voice-overs keep going). One undo step; the recording is never touched.
    func freezeFrame() async {
        guard isReady, !isImportingMedia else { return }
        let time = player.currentTime
        let timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: time)
        let segment = timeline.segments[index]
        let url = segment.sourceID.flatMap { clipSourceURLs[$0] } ?? videoURL
        isImportingMedia = true
        defer { isImportingMedia = false }
        player.pause()
        toast.show(String(localized: "Freezing the frame…"))
        let name: String
        do {
            name = try await editing.stillClip(ofVideoAt: url, at: timeline.sourceTime(forEdited: time), length: Self.freezeFileLength)
        } catch {
            toast.show(String(localized: "Can't freeze this frame"))
            return
        }
        guard !isClosed else {
            EditMediaFiles.remove([name])
            return
        }
        // The frame took a moment (about 2 s in 4K): if the cuts changed meanwhile, the place it was for may be gone.
        guard edit.timeline == timeline else {
            EditMediaFiles.remove([name])
            toast.show(String(localized: "The video changed meanwhile · Freeze the frame again"))
            return
        }
        importedFiles.insert(name)
        var next = arranged(edit)
        let at: Int
        if next.timeline.split(atEdited: time) {
            at = index + 1
        } else {
            // Too close to an edge to split: before the clip near its start, after it near its end.
            let start = timeline.editedStart(ofSegmentAt: index)
            at = time - start < segment.duration / 2 ? index : index + 1
        }
        // The clip's look, and the background its recording plays with (the frozen frame is a recording of its own).
        var look = segment.look ?? ClipLook()
        if look.background == nil, let background = edit.background(for: segment) { look.background = background }
        let source = ClipSource(fileName: name, duration: Self.freezeFileLength, title: String(localized: "Freeze frame"))
        guard let id = next.timeline.insertClip(
            source: source.id, duration: source.duration, span: TimeSpan(start: 0, end: Self.freezeLength), at: at,
            look: look.isEmpty ? nil : look
        ), let inserted = next.timeline.index(ofSegment: id) else { return }
        next.sources.append(source)
        commit(EditSnapshot(next))
        player.seek(to: next.timeline.editedStart(ofSegmentAt: inserted))
        toast.show(
            String(localized: "Frame frozen for \(Int(Self.freezeLength)) seconds · drag its end to hold longer"),
            action: undoAction
        )
    }

    // MARK: - Private

    /// `edit` ready to be arranged: pinned to its sections the first time.
    func arranged(_ edit: TakeEdit) -> TakeEdit {
        var next = edit
        if !next.timeline.isArranged { next.anchorOverlays() }
        return next
    }

    private func title(ofSource id: UUID?) -> String {
        guard let id else { return String(localized: "This take") }
        return edit.sources.first { $0.id == id }?.title ?? String(localized: "Video")
    }
}
