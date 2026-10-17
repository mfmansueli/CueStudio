//
//  QuickEditViewModel+Reverse.swift
//  Cue Studio
//

import Foundation

/// Reverse (clip toolbar): the picked clip plays backwards, picture and sound. Its stretch of the recording is written
/// backwards as a video of its own in the edit's media (`ReversedClipWriter`, off the main thread) and the clip plays that
/// instead, keeping its speed, look and place; texts and photos on it stay where they are in the video. Reversing it again puts
/// the original back. One undo step; the recording is never touched.
extension QuickEditViewModel {
    /// Longest clip Reverse writes.
    static var longestReverse: TimeInterval { ReversedClipWriter.longest }

    func reverseClip() async {
        guard isReady, !isImportingMedia, let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
        player.pause()
        if let source = clip.sourceID.flatMap({ id in edit.sources.first { $0.id == id } }), let reversal = source.reversal {
            putBack(clip, at: index, from: reversal)
            return
        }
        guard clip.sourceLength <= Self.longestReverse + 0.001 else {
            toast.show(String(localized: "Reverse works on clips up to 2 minutes · Split it first"))
            return
        }
        let url = clip.sourceID.flatMap { clipSourceURLs[$0] } ?? videoURL
        let timeline = edit.timeline
        isImportingMedia = true
        defer { isImportingMedia = false }
        toast.show(String(localized: "Reversing the clip…"))
        let name: String
        do {
            name = try await ReversedClipWriter.write(url, span: clip.span) { _ in }
        } catch {
            toast.show(String(localized: "Can’t reverse this clip"))
            return
        }
        guard edit.timeline == timeline else {
            EditMediaFiles.remove([name])
            toast.show(String(localized: "The video changed meanwhile · Reverse it again"))
            return
        }
        importedFiles.insert(name)
        var source = ClipSource(fileName: name, duration: clip.sourceLength, title: String(localized: "\(title(ofClip: clip)) · Reversed"))
        source.reversal = ClipReversal(sourceID: clip.sourceID, span: clip.span)
        replace(clip, at: index, with: source.id, duration: source.duration, span: TimeSpan(start: 0, end: clip.sourceLength), adding: source)
        toast.show(
            String(localized: "Reversed"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
        )
    }

    /// The clip plays its original again.
    private func putBack(_ clip: EditSegment, at index: Int, from reversal: ClipReversal) {
        let original = reversal.original(of: clip.span)
        let duration = edit.timeline.duration(ofSource: reversal.sourceID)
        replace(clip, at: index, with: reversal.sourceID, duration: duration, span: original, adding: nil)
        toast.show(String(localized: "Plays forward again"))
    }

    /// The clip at `index` playing `span` of another recording, as one step; what's laid on it stays where it is in the video.
    private func replace(_ clip: EditSegment, at index: Int, with source: UUID?, duration: TimeInterval, span: TimeSpan, adding: ClipSource?) {
        var next = edit
        if !next.timeline.isArranged { next.anchorOverlays() }
        let before = next.timeline
        let texts = next.texts.indices.compactMap { position -> (Int, TimeSpan)? in
            guard next.texts[position].clipAnchor?.segmentID == clip.id,
                  let span = TakeEdit.editedSpan(next.texts[position].span, anchor: next.texts[position].clipAnchor, in: before) else { return nil }
            return (position, span)
        }
        let media = next.media.indices.compactMap { position -> (Int, TimeSpan)? in
            guard next.media[position].clipAnchor?.segmentID == clip.id,
                  let span = TakeEdit.editedSpan(next.media[position].span, anchor: next.media[position].clipAnchor, in: before) else { return nil }
            return (position, span)
        }
        guard next.timeline.replaceSource(ofSegmentAt: index, with: source, duration: duration, span: span) else { return }
        if let adding { next.sources.append(adding) }
        for (position, span) in texts {
            let pinned = next.pin(span)
            next.texts[position].clipAnchor = pinned.anchor
            next.texts[position].span = pinned.span
        }
        for (position, span) in media {
            let pinned = next.pin(span)
            next.media[position].clipAnchor = pinned.anchor
            next.media[position].span = pinned.span
        }
        commit(EditSnapshot(next))
    }

    private func title(ofClip clip: EditSegment) -> String {
        guard let id = clip.sourceID else { return take.scriptTitle.isEmpty ? String(localized: "This take") : take.scriptTitle }
        return edit.sources.first { $0.id == id }?.title ?? String(localized: "Video")
    }
}
