//
//  BlurViewModel+Adding.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Blur area's first step: the footage under the playhead (the picked photo or video over the take, else the clip there, a
/// reversed or frozen clip read as the recording it shows), its faces numbered on the preview (from the motion analysis when it
/// reached there, else Vision on that frame), and a tap that makes the area: on a face (with room for the head and hair,
/// followed at once), on every face but the largest (the creator, usually), or drawn for anything else.
extension BlurViewModel {
    /// The area a drawn Blur area starts as: a strip like a plate or a line of text, as a share of the frame.
    static let drawnSize = CGSize(width: 0.36, height: 0.12)

    /// The footage a new area would go on now; nil where the playhead shows none (a gap past the end).
    func footageUnderPlayhead() -> BlurFootage? {
        let time = player.currentTime
        let timeline = edit.timeline
        if let media = selectedMedia, let fileTime = media.fileTime(at: time, in: timeline) {
            let isVideo = media.kind == .video
            let length = media.mediaDuration ?? 1
            return BlurFootage(
                target: .media(media.id), time: isVideo ? fileTime : 0, url: EditMediaFiles.url(for: media.fileName), isVideo: isVideo,
                span: TimeSpan(start: 0, end: max(BlurRegion.shortest, length))
            )
        }
        guard !timeline.segments.isEmpty else { return nil }
        let index = timeline.segmentIndex(atEdited: time)
        let segment = timeline.segments[index]
        let start = timeline.editedStart(ofSegmentAt: index)
        let played = min(segment.sourceEnd, segment.sourceStart + segment.sourceOffset(forEdited: max(0, time - start)))
        let source = segment.sourceID.flatMap { id in edit.sources.first { $0.id == id } }
        // A reversed clip shows another recording read backwards, a frozen frame another one's second: the area goes on that one.
        if let source, let reversal = source.reversal {
            let target = BlurTarget.recording(reversal.sourceID)
            guard let url = url(of: target) else { return nil }
            let span = TimeSpan(start: reversal.span.end - segment.sourceEnd, end: reversal.span.end - segment.sourceStart)
            return BlurFootage(target: target, time: reversal.span.end - played, url: url, isVideo: true, span: span)
        }
        if let source, let still = source.still {
            let target = BlurTarget.recording(still.sourceID)
            guard let url = url(of: target) else { return nil }
            let span = TimeSpan(start: max(0, still.time - BlurRegion.shortest / 2), end: still.time + BlurRegion.shortest / 2)
            return BlurFootage(target: target, time: still.time, url: url, isVideo: true, span: span)
        }
        let target = BlurTarget.recording(segment.sourceID)
        guard let url = url(of: target) else { return nil }
        return BlurFootage(target: target, time: played, url: url, isVideo: true, span: segment.span)
    }

    /// "Blur area": the faces in the frame under the playhead, to tap one, or an area to draw.
    func startAdding() {
        guard isReady else { return }
        player.pause()
        guard let footage = footageUnderPlayhead() else {
            toast.show(String(localized: "Move the playhead onto the video"), kind: .problem)
            return
        }
        selection = footage.target.mediaID.map(EditorSelection.media)
        picking = BlurPicking(footage: footage)
        panel = .blur
        loadUprightSize(of: footage.url, isVideo: footage.isVideo)
        Task { await findFaces(for: footage) }
    }

    /// The faces of `footage` at its second, into `picking`.
    func findFaces(for footage: BlurFootage) async {
        let found = await faces(in: footage)
        guard picking?.footage == footage else { return }
        picking?.faces = found
        picking?.isSearching = false
    }

    /// Faces of a footage at its second, largest first: from the recording's motion analysis when it reached there (instant),
    /// else Vision on that frame.
    func faces(in footage: BlurFootage) async -> [NormalizedBox] {
        if !footage.target.isMedia {
            let url = footage.url, time = footage.time
            let analyzed = await Task.detached(priority: .userInitiated) { () -> [NormalizedBox]? in
                guard let analysis = MotionAnalysisStore.load(forRecording: url), analysis.isCurrent, analysis.analyzedUntil >= time else { return nil }
                return BlurFollowing.faces(in: analysis.subjects, at: time)
            }.value
            // The analysis reads a small copy: where it found nobody, Vision on the whole frame may still find a small face.
            if let analyzed, !analyzed.isEmpty { return analyzed.sorted { $0.area > $1.area } }
        }
        let boxes = await faces.faces(in: footage.url, isVideo: footage.isVideo, at: footage.time) ?? []
        return boxes.map { NormalizedBox(x: $0.minX, y: $0.minY, width: $0.width, height: $0.height) }
    }

    /// A tap on face `index` of the first step: an area over it, picked, followed at once.
    func pickFace(_ index: Int) {
        guard let picking, picking.faces.indices.contains(index) else { return }
        let region = makeFaceRegion(picking.faces[index], on: picking.footage)
        add([region], toast: String(localized: "Face hidden · Tracking it"))
        follow(region.id)
    }

    /// Every face but the largest (the creator, most of the time): an area over each, followed one after another.
    func pickAllButLargest() {
        guard let picking, picking.faces.count > 1 else { return }
        let regions = picking.faces.dropFirst().map { makeFaceRegion($0, on: picking.footage) }
        add(regions, toast: String(localized: "\(regions.count) faces hidden · Tracking them"))
        followQueue = regions.dropFirst().map(\.id)
        if let first = regions.first { follow(first.id) }
    }

    /// An area drawn in the middle of what shows, to drag onto a plate, a name or anything else; it stays put until followed.
    func drawArea() {
        guard let footage = picking?.footage ?? footageUnderPlayhead() else { return }
        let frame = CGRect(
            x: 0.5 - Self.drawnSize.width / 2, y: 0.5 - Self.drawnSize.height / 2, width: Self.drawnSize.width, height: Self.drawnSize.height
        )
        let box = footageBox(for: frame, on: footage.target) ?? NormalizedBox(center: CGPoint(x: 0.5, y: 0.5), width: 0.3, height: 0.1)
        var region = BlurRegion(target: footage.target, span: footage.span, box: box)
        region.style = .solid
        add([region], toast: String(localized: "Drag it onto what to hide"))
    }

    // MARK: - Private

    private func makeFaceRegion(_ face: NormalizedBox, on footage: BlurFootage) -> BlurRegion {
        BlurRegion(target: footage.target, span: footage.span, box: BlurRegion.area(aroundFace: face), subject: .face)
    }

    /// Adds `regions` in one undo step and picks the first; the first step ends.
    private func add(_ regions: [BlurRegion], toast message: String) {
        guard let first = regions.first else { return }
        change { snapshot in
            var all = snapshot.blurRegions ?? []
            all += regions
            snapshot.blurRegions = all
        }
        picking = nil
        selection = .blur(first.id)
        panel = .blur
        Haptics.selection()
        sayUndoable(message)
    }
}
