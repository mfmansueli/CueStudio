//
//  EditorPart+Clips.swift
//  Cue Studio
//

import Foundation

/// The clips every part speaks of: the one under the playhead, the one a clip tool works on (the picked one, else the one under
/// the playhead) and how a panel names it, a change to it as an undo step, and the file each recording is read from.
extension EditorPart {
    /// The clip under the playhead.
    var clipIndexAtPlayhead: Int {
        edit.timeline.segmentIndex(atEdited: player.currentTime)
    }

    /// The clip a clip panel works on: the picked one, else the one under the playhead.
    var targetClip: EditSegment? {
        if let id = selection?.clipID, let segment = edit.timeline.segment(id: id) { return segment }
        let segments = edit.timeline.segments
        return segments.indices.contains(clipIndexAtPlayhead) ? segments[clipIndexAtPlayhead] : segments.first
    }

    /// Which clip a clip panel changes: "This clip" while the video is one clip, else "Clip 2 of 3", so the creator always knows
    /// where the change lands.
    var clipScope: String {
        let segments = edit.timeline.segments
        guard segments.count > 1, let id = targetClip?.id, let index = segments.firstIndex(where: { $0.id == id }) else {
            return String(localized: "This clip")
        }
        return String(localized: "Clip \(index + 1) of \(segments.count)")
    }

    /// Changes the picked clip (or the one under the playhead) as an undo step.
    func updateClip(key: String? = nil, _ update: (inout EditSegment) -> Void) {
        guard var clip = targetClip else { return }
        update(&clip)
        var timeline = edit.timeline
        guard timeline.replaceSegment(clip), timeline != edit.timeline else { return }
        commit(timeline, key: key.map { "\($0).\(clip.id)" })
    }

    /// The montage's other recordings' files, by source.
    var clipSourceURLs: [UUID: URL] {
        Dictionary(edit.sources.map { ($0.id, EditMediaFiles.url(for: $0.fileName)) }) { first, _ in first }
    }

    /// The file a recording is read from: the take's own (nil), or a montage's other recording.
    func recordingURL(of sourceID: UUID?) -> URL? {
        guard let sourceID else { return session.videoURL }
        return edit.sources.first { $0.id == sourceID }.map { EditMediaFiles.url(for: $0.fileName) }
    }
}
