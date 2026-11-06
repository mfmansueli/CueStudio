//
//  ClipsViewModel+Reverse.swift
//  Cue Studio
//

import Foundation

/// Reverse (clip toolbar): the picked clip plays backwards, picture and sound. Its stretch of the recording is written
/// backwards as a video of its own in the edit's media (`ReversedClipWriter`, off the main thread) and the clip plays that
/// instead, keeping its speed, look and place; texts, photos and voice-overs on it stay where they are in the video. Reversing
/// it again puts the original back; reversing it once more plays the reversed video already written (it covers the clip), so
/// going back and forth never writes another file. One undo step; the recording is never touched. Reversed videos the edit no
/// longer plays leave it on Done (`QuickEditViewModel.done`).
extension ClipsViewModel {
    /// Longest clip Reverse writes.
    static var longestReverse: TimeInterval { ReversedClipWriter.longest }

    func reverseClip() async {
        guard isReady, !isImportingMedia, let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
        player.pause()
        if let reversal = reversal(of: clip) {
            putBack(clip, at: index, from: reversal)
            return
        }
        if let written = reversedSource(covering: clip) {
            let span = written.reversal.map { TimeSpan(start: $0.span.end - clip.sourceEnd, end: $0.span.end - clip.sourceStart) }
                ?? TimeSpan(start: 0, end: clip.sourceLength)
            replace(clip, at: index, with: written.id, duration: written.duration, span: span, adding: nil)
            toast.show(String(localized: "Reversed"), action: undoAction)
            return
        }
        guard clip.sourceLength <= Self.longestReverse + 0.001 else {
            toast.show(String(localized: "Reverse works on clips up to 2 minutes · Split it first"), kind: .problem)
            return
        }
        let url = clip.sourceID.flatMap { clipSourceURLs[$0] } ?? videoURL
        let timeline = edit.timeline
        isImportingMedia = true
        work = EditorWork(kind: .reversing, job: .reverse)
        defer {
            isImportingMedia = false
            if work?.job == .reverse { work = nil }
        }
        let name: String
        do {
            name = try await ReversedClipWriter.write(url, span: clip.span) { [weak self] fraction in
                Task { @MainActor in self?.reportWork(.reverse, fraction) }
            }
        } catch is CancellationError {
            // Cancel on the pill, or the editor closed: the clip stays as it was.
            return
        } catch {
            noteFailure(error, "reverse")
            toast.show(String(localized: "Can’t reverse this clip"), kind: .problem)
            return
        }
        // Cancelled as it finished, or closed meanwhile: nothing will play it.
        guard !Task.isCancelled, !isClosed else {
            EditMediaFiles.remove([name])
            return
        }
        guard edit.timeline == timeline else {
            EditMediaFiles.remove([name])
            toast.show(String(localized: "The video changed meanwhile · Reverse it again"), kind: .problem)
            return
        }
        importedFiles.insert(name)
        var source = ClipSource(fileName: name, duration: clip.sourceLength, title: String(localized: "\(title(ofClip: clip)) · Reversed"))
        source.reversal = ClipReversal(sourceID: clip.sourceID, span: clip.span)
        replace(clip, at: index, with: source.id, duration: source.duration, span: TimeSpan(start: 0, end: clip.sourceLength), adding: source)
        toast.show(
            String(localized: "Reversed"),
            action: undoAction
        )
    }

    /// The clip plays its original again.
    private func putBack(_ clip: EditSegment, at index: Int, from reversal: ClipReversal) {
        playForward(clip, at: index, from: reversal)
        toast.show(String(localized: "Plays forward again"))
    }

    /// The reversed clip at `index` plays its original stretch forward again, as one step.
    func playForward(_ clip: EditSegment, at index: Int, from reversal: ClipReversal) {
        let original = reversal.original(of: clip.span)
        let duration = edit.timeline.duration(ofSource: reversal.sourceID)
        replace(clip, at: index, with: reversal.sourceID, duration: duration, span: original, adding: nil)
    }

    /// What `clip` plays backwards, nil when it plays its recording forward.
    func reversal(of clip: EditSegment) -> ClipReversal? {
        clip.sourceID.flatMap { id in edit.sources.first { $0.id == id } }?.reversal
    }

    /// A reversed video of the edit that covers the clip's stretch of its recording (written by an earlier Reverse of it).
    private func reversedSource(covering clip: EditSegment) -> ClipSource? {
        edit.sources.first { source in
            guard let reversal = source.reversal, reversal.sourceID == clip.sourceID else { return false }
            return reversal.span.start <= clip.sourceStart + 0.001 && clip.sourceEnd <= reversal.span.end + 0.001
        }
    }

    /// The clip at `index` playing `span` of another recording, as one step; what's laid on it stays where it is in the video.
    private func replace(_ clip: EditSegment, at index: Int, with source: UUID?, duration: TimeInterval, span: TimeSpan, adding: ClipSource?) {
        var next = edit
        if !next.timeline.isArranged { next.anchorOverlays() }
        let before = next.timeline
        // What starts on it as it plays (after a split, the right part's layers still name the left part).
        let on = next.layersStarting(onSegment: clip.id)
        let texts = on.texts.compactMap { position -> (Int, TimeSpan)? in
            TakeEdit.editedSpan(next.texts[position].span, anchor: next.texts[position].clipAnchor, in: before).map { (position, $0) }
        }
        let media = on.media.compactMap { position -> (Int, TimeSpan)? in
            next.media[position].editedSpan(in: before).map { (position, $0) }
        }
        let voices = on.voiceOvers.compactMap { position -> (Int, TimeInterval)? in
            next.voiceOvers[position].editedSpan(in: before).map { (position, $0.start) }
        }
        guard next.timeline.replaceSource(ofSegmentAt: index, with: source, duration: duration, span: span) else { return }
        if let adding { next.sources.append(adding) }
        for (position, span) in texts {
            let pinned = next.pin(span)
            next.texts[position].clipAnchor = pinned.anchor
            next.texts[position].span = pinned.span
        }
        for (position, span) in media {
            next.layMedia(at: position, over: span)
        }
        for (position, start) in voices {
            let pinned = next.pin(TimeSpan(start: start, end: start + 0.05))
            next.voiceOvers[position].clipAnchor = pinned.anchor
            next.voiceOvers[position].anchor = pinned.span.start
        }
        commit(EditSnapshot(next))
    }

    private func title(ofClip clip: EditSegment) -> String {
        guard let id = clip.sourceID else { return take.scriptTitle.isEmpty ? String(localized: "This take") : take.scriptTitle }
        return edit.sources.first { $0.id == id }?.title ?? String(localized: "Video")
    }
}
