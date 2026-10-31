//
//  OverlaysViewModel+Media.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import PhotosUI
import SwiftUI

/// Media (B-roll): a photo or video from the library over the take, full screen or in a window
/// the creator places, sizes and crops. Added at the playhead in the free room there (one at a
/// time), shown for 3 seconds (a photo) or its length (a video), then moved or stretched on the
/// media track. The picked file is copied into the app, so the edit never depends on the library.
extension OverlaysViewModel {
    /// Copies the picked photo or video in and adds it at the playhead.
    func importMedia(_ item: PhotosPickerItem) async {
        guard isReady, !isImportingMedia else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            let imported = try await importPicked(item)
            guard !isClosed else {
                EditMediaFiles.remove([imported.fileName])
                return
            }
            addMedia(imported)
        } catch is CancellationError {
            // Cancel on the pill, or the editor closed: nothing to say.
        } catch {
            noteFailure(error, "importMedia")
            toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Can't add this file")), kind: .problem)
        }
    }

    /// Adds what was copied in at the playhead, on top of what's there, for its length (a photo's
    /// three seconds) or until the end. Up to `MediaOverlay.simultaneousLimit` show at once.
    /// "Starts at 00:07.0 · a photo stays 3 s, a video plays its length": where a pick laid over the video lands (`addMedia`),
    /// under the choice.
    var insertionNote: String {
        let start = min(player.currentTime, max(0, edit.editedDuration - MediaOverlay.minimumDuration))
        let photo = Int(MediaOverlay.photoDuration.rounded())
        return String(localized: "Starts at \(DurationText.editor(start)) · a photo stays \(photo) s, a video plays its length")
    }

    func addMedia(_ imported: ImportedMedia) {
        importedFiles.insert(imported.fileName)
        let total = edit.editedDuration
        let wanted = imported.kind == .photo ? MediaOverlay.photoDuration : (imported.duration ?? MediaOverlay.photoDuration)
        let start = min(player.currentTime, max(0, total - MediaOverlay.minimumDuration))
        let end = min(start + wanted, total)
        let placed = TimeSpan(start: start, end: end)
        guard end - start >= MediaOverlay.minimumDuration else {
            EditMediaFiles.remove([imported.fileName])
            importedFiles.remove(imported.fileName)
            toast.show(String(localized: "No room · Move the playhead"), kind: .problem)
            return
        }
        guard LayerLanes.peak(of: limitedMediaSpans(), within: placed) < MediaOverlay.simultaneousLimit else {
            EditMediaFiles.remove([imported.fileName])
            importedFiles.remove(imported.fileName)
            toast.show(String(localized: "Max 3 photos or videos"), kind: .problem)
            return
        }
        var media = MediaOverlay(
            kind: imported.kind, fileName: imported.fileName, aspect: imported.aspect,
            mediaDuration: imported.duration, span: placed
        )
        media.followsCuts = true
        media.hasSound = imported.kind == .video ? imported.hasSound : nil
        media.layer = (edit.media.map(\.stackOrder).max() ?? -1) + 1
        var next = edit
        next.media.append(media)
        next.layMedia(at: next.media.count - 1, over: placed)
        commit(EditSnapshot(next))
        selectedMediaID = media.id
        // Muted until the creator says to keep its sound.
        if imported.kind == .video, imported.hasSound { soundChoiceMediaID = media.id }
        player.pause()
        player.seek(to: start)
        let place = DurationText.editor(start)
        sayUndoable(imported.kind == .photo ? String(localized: "Photo added at \(place)") : String(localized: "Video added at \(place)"))
    }

    /// Answers "keep its sound?" for a video just added: kept at full volume, or muted.
    func chooseSound(for id: UUID, keeps: Bool) {
        if soundChoiceMediaID == id { soundChoiceMediaID = nil }
        if keeps { setMediaSoundVolume(id, 1) }
    }

    /// A video's own sound: 0 mutes it.
    func setMediaSoundVolume(_ id: UUID, _ volume: Double) {
        let clamped = min(max(volume, 0), 1)
        updateMedia(id) { $0.audioVolume = clamped > 0.001 ? clamped : nil }
    }

    func updateMedia(_ id: UUID, _ update: (inout MediaOverlay) -> Void) {
        change { snapshot in
            guard let index = snapshot.media.firstIndex(where: { $0.id == id }) else { return }
            update(&snapshot.media[index])
        }
    }

    /// Moves a photo or video one step up (over the one above it) or down, in one undo step.
    func restack(_ id: UUID, up: Bool) {
        change { snapshot in
            // Normalize the order first (media from before stacking share the bottom).
            let ordered = snapshot.media.enumerated().sorted { ($0.element.stackOrder, $0.offset) < ($1.element.stackOrder, $1.offset) }.map(\.element.id)
            guard let position = ordered.firstIndex(of: id) else { return }
            let target = up ? position + 1 : position - 1
            guard ordered.indices.contains(target) else { return }
            var order = ordered
            order.swapAt(position, target)
            for (layer, mediaID) in order.enumerated() {
                if let index = snapshot.media.firstIndex(where: { $0.id == mediaID }) { snapshot.media[index].layer = layer }
            }
        }
    }

    /// Whether the picked photo or video can go up (or down) a step.
    func canRestack(_ id: UUID, up: Bool) -> Bool {
        let ordered = edit.media.enumerated().sorted { ($0.element.stackOrder, $0.offset) < ($1.element.stackOrder, $1.offset) }.map(\.element.id)
        guard let position = ordered.firstIndex(of: id) else { return false }
        return up ? position < ordered.count - 1 : position > 0
    }

    /// A copy of the photo or video on top of the others, a little lower when it doesn't fill the frame, picked. The file is
    /// shared (it goes only when nothing names it).
    func duplicateMedia(_ id: UUID) {
        guard let original = edit.media.first(where: { $0.id == id }) else { return }
        // The copy shows over the same moment: never more than the export draws at once (a still logo's copy is one too).
        let shown = mediaBars.first { $0.id == id }?.span ?? original.span
        guard original.isStaticLogo || LayerLanes.peak(of: limitedMediaSpans(), within: shown) < MediaOverlay.simultaneousLimit else {
            toast.show(String(localized: "Max 3 photos or videos"), kind: .problem)
            return
        }
        var copy = original
        copy.id = UUID()
        copy.layer = (edit.media.map(\.stackOrder).max() ?? 0) + 1
        if copy.layout != .fullFrame {
            copy.center = OverlayPoint(x: original.center.x, y: min(0.9, original.center.y + 0.08)).clamped
        }
        change { snapshot in
            snapshot.media.append(copy)
            // The copy shows the same file: its Blur areas come along.
            let copies = (snapshot.blurRegions ?? []).filter { $0.target.mediaID == id }.map { region in
                var area = region
                area.id = UUID()
                area.target = .media(copy.id)
                return area
            }
            snapshot.blurRegions = (snapshot.blurRegions ?? []) + copies
        }
        selection = .media(copy.id)
        sayUndoable(String(localized: "Media duplicated"))
    }

    /// Takes the photo or video out (Undo brings it back). A support leaves its space: the main video has the whole frame there.
    func deleteMedia(_ id: UUID) {
        let wasSupport = edit.media.first { $0.id == id }?.layout == .split
        change { $0.media.removeAll { $0.id == id } }
        Haptics.delete()
        sayUndoable(wasSupport ? String(localized: "Support removed · the main video fills the frame there") : String(localized: "Media removed"))
    }

    // MARK: - The part of a video

    /// Plays another part of the video (`start`, seconds of the file) in the same place of the edit, for as long as it shows
    /// there; kept inside the file. A drag is one undo step (`beginChange`).
    func slipMedia(_ id: UUID, toStart start: TimeInterval) {
        guard let media = edit.media.first(where: { $0.id == id }), let length = media.mediaDuration else { return }
        let clamped = min(max(0, start), max(0, length - fileUsed(by: media)))
        updateMedia(id) { $0.mediaStart = clamped > 0.000_1 ? clamped : nil }
    }

    /// How much of its file a video goes through where it shows: the time it shows, and the stretches cut out of the speech
    /// under it (`MediaOverlay.pieces`).
    func fileUsed(by media: MediaOverlay) -> TimeInterval {
        let pieces = media.pieces(in: edit.timeline)
        guard let first = pieces.first, let last = pieces.last else { return 0 }
        return last.fileEnd - first.fileStart
    }

    /// How long the photo or video shows, from where it starts in the edit: longer is as far as the video (from its part) and the
    /// edit allow. One undo step per tap.
    func setMediaLength(_ id: UUID, _ seconds: TimeInterval) {
        guard let media = edit.media.first(where: { $0.id == id }), let bar = mediaBars.first(where: { $0.id == id }) else { return }
        var end = edit.editedDuration
        // A support stops where the next one starts: one shows at a time.
        if media.layout == .split, let next = supportSpans.map(\.span.start).filter({ $0 > bar.span.start + 0.001 }).min() { end = min(end, next) }
        let longest = min(media.longestDuration, end - bar.span.start)
        let length = min(max(seconds, MediaOverlay.minimumDuration), longest)
        guard abs(length - bar.span.duration) > 0.01 else { return }
        let span = TimeSpan(start: bar.span.start, end: bar.span.start + length)
        // Longer only while no more than the export draws at once show then.
        guard length < bar.span.duration || mediaFits(media, over: span) else {
            toast.show(String(localized: "3 photos or videos already show then · up to 3 at a time"), kind: .problem)
            return
        }
        layMedia(id, over: span)
    }

    /// Its place on a preview of `size` (from the top left), as the export places it.
    func frame(ofMedia media: MediaOverlay, in size: CGSize) -> CGRect {
        let placed = MediaPlacement.rect(for: media, in: size)
        guard media.keyframes?.isEmpty == false else { return placed }
        // Where its keyframes have it at the playhead.
        let state = motionState(of: .media(media.id))
        let width = placed.width * CGFloat(state.scale)
        let height = placed.height * CGFloat(state.scale)
        return CGRect(
            x: CGFloat(state.center.clamped.x) * size.width - width / 2,
            y: CGFloat(state.center.clamped.y) * size.height - height / 2,
            width: width, height: height
        )
    }

    // MARK: - Replacing

    /// Copies the picked file in and swaps it for the one on the media track; a video longer than the slot first asks which
    /// part of it fills the slot (`partChoice`).
    func replaceMedia(_ id: UUID, importing item: PhotosPickerItem) async {
        guard isReady, !isImportingMedia else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            let imported = try await importPicked(item)
            guard let slot = mediaBars.first(where: { $0.id == id })?.span.duration else {
                EditMediaFiles.remove([imported.fileName])
                return
            }
            if imported.kind == .video, let length = imported.duration, length > slot + 0.05 {
                importedFiles.insert(imported.fileName)
                partChoice = MediaPartChoice(purpose: .replaceMedia(id), pick: MediaPick(imported), length: slot)
            } else {
                replaceMedia(id, with: MediaPick(imported))
            }
        } catch is CancellationError {
            // Cancel on the pill, or the editor closed: nothing to say.
        } catch {
            noteFailure(error, "replaceMedia")
            toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Can't add this file")), kind: .problem)
        }
    }

    /// Puts `pick` in the place of a photo or video: where it shows and for how long (a video with less left than that shows
    /// for what it has), its layout, window, framing, motion and keyframes stay; its sound keeps its level when the new video
    /// has sound. A photo can take a video's place and a video a photo's. One undo step.
    func replaceMedia(_ id: UUID, with pick: MediaPick) {
        let imported = pick.imported
        guard !isClosed, let index = edit.media.firstIndex(where: { $0.id == id }),
              let span = mediaBars.first(where: { $0.id == id })?.span else {
            EditMediaFiles.remove([imported.fileName])
            return
        }
        let old = edit.media[index]
        var media = old
        media.kind = imported.kind
        // A still logo replaced by a video counts again: only where the others leave it room.
        guard !old.isStaticLogo || mediaFits(media, over: span) else {
            EditMediaFiles.remove([imported.fileName])
            toast.show(String(localized: "3 photos or videos already show then · up to 3 at a time"), kind: .problem)
            return
        }
        importedFiles.insert(imported.fileName)
        var next = edit
        media.fileName = imported.fileName
        media.aspect = imported.aspect.isFinite && imported.aspect > 0 ? imported.aspect : 1
        media.mediaDuration = imported.duration
        media.mediaStart = imported.kind == .video && pick.start > 0.000_1 ? pick.start : nil
        media.hasSound = imported.kind == .video ? imported.hasSound : nil
        if imported.kind != .video || !imported.hasSound { media.audioVolume = nil }
        // Its voice's captions were the old video's words: they go with it (Undo brings both back).
        let hadVoiceCaptions = old.captionsItsVoice == true
        media.captionsItsVoice = nil
        // The framing's zoom and fit stay; the new picture starts centered.
        if var framing = media.areaFraming {
            framing.center = .center
            media.areaFraming = framing
        }
        if var framing = media.pictureFraming {
            framing.center = .center
            media.pictureFraming = framing
        }
        next.media[index] = media
        next.captions.removeAll { $0.sourceID == id }
        // A Blur area was on the old picture's seconds and places: it doesn't cover the new one (Undo brings both back).
        let hidBlur = next.blurRegions.contains { $0.target.mediaID == id }
        next.blurRegions.removeAll { $0.target.mediaID == id }
        var shown = span
        if imported.kind == .video, let length = imported.duration {
            shown.end = min(span.end, span.start + max(MediaOverlay.minimumDuration, length - pick.start))
        }
        next.layMedia(at: index, over: shown)
        commit(EditSnapshot(next))
        if hadVoiceCaptions { updateFindings { $0.sourceTranscripts.removeAll { $0.sourceID == id } } }
        // Both went with the old picture: the toast tells both, so neither leaves without a word (F3).
        if hidBlur, hadVoiceCaptions {
            toast.show(
                String(localized: "Replaced · its Blur area and its voice's captions went with the old one"), kind: .problem, action: undoAction
            )
            return
        }
        if hidBlur {
            toast.show(String(localized: "Replaced · its Blur area was on the old one"), kind: .problem, action: undoAction)
            return
        }
        if hadVoiceCaptions {
            sayUndoable(String(localized: "Replaced · its voice's captions went with the old one"))
            return
        }
        let shorter = shown.duration + 0.05 < span.duration
        let message = switch (imported.kind, shorter) {
        case (.photo, _): String(localized: "Photo in its place · place and settings kept")
        case (.video, true): String(localized: "Video in its place · it’s shorter, so it ends sooner")
        case (.video, false): String(localized: "Video in its place · place and settings kept")
        }
        sayUndoable(message)
    }

}
