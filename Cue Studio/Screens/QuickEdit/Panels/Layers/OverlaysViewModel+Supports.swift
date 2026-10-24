//
//  OverlaysViewModel+Supports.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import PhotosUI
import SwiftUI

/// Photos and videos picked in "Add photo or video" going in, one after the other from the playhead (`MediaRun`), and the
/// split screen they make: its layout, how each content sits in its area, and the two sounds. A support is a photo or video
/// with the split layout; the main video keeps playing in the other area, and has the whole frame back where none shows.
extension OverlaysViewModel {
    // MARK: - Where picked media goes

    /// The supports of the split screen where they show, in the order they play.
    var supportSpans: [(id: UUID, span: TimeSpan)] {
        edit.placedMedia(in: edit.timeline).filter { $0.media.layout == .split }.map { ($0.media.id, $0.span) }
    }

    /// Where what is picked for `mode` starts: the playhead; for the split screen, after the support playing there (one shows at
    /// a time).
    func runStart(for mode: MediaInsertMode) -> TimeInterval {
        let playhead = min(player.currentTime, max(0, edit.editedDuration - MediaOverlay.minimumDuration))
        guard mode == .split,
              let playing = supportSpans.first(where: { $0.span.start - 0.001 <= playhead && playhead < $0.span.end - 0.05 }) else { return playhead }
        return playing.span.end
    }

    /// How long what is picked for `mode` can go on from `start`: to the end of the video; for the split screen, to the next
    /// support. The edit never grows to make room.
    func runRoom(for mode: MediaInsertMode, from start: TimeInterval) -> TimeInterval {
        var end = edit.editedDuration
        if mode == .split, let next = supportSpans.map(\.span.start).filter({ $0 > start + 0.001 }).min() { end = min(end, next) }
        return max(0, end - start)
    }

    /// How `picks` would go in for `mode`, from where they'd start.
    func run(of picks: [MediaPick], as mode: MediaInsertMode) -> MediaRun {
        let start = runStart(for: mode)
        return MediaRun(lengths: picks.map(\.wanted), from: start, room: runRoom(for: mode, from: start))
    }

    /// "00:07.0 to 00:28.5 · 3 videos, 21.5 s", and what doesn't fit, said before anything goes in.
    func runNote(_ run: MediaRun, count: Int) -> String {
        guard let first = run.placed.first, let end = run.end else {
            return String(localized: "No room here · Move the playhead")
        }
        let place = String(localized: "\(DurationText.editor(first.span.start)) to \(DurationText.editor(end))")
        if run.leftOut > 0 {
            return String(localized: "\(place) · \(run.leftOut) don’t fit before the end and stay out")
        }
        if run.placed.last?.isShortened == true {
            return count == 1
                ? String(localized: "\(place) · shortened to fit before the end")
                : String(localized: "\(place) · the last one is shortened to fit")
        }
        return place
    }

    /// "Starts at 00:07.0 · room until 00:30.0": where what is picked for `mode` would start and how far it can go, under the
    /// choice, before picking.
    func insertionNote(for mode: MediaInsertMode) -> String {
        let start = runStart(for: mode)
        let room = runRoom(for: mode, from: start)
        guard room >= MediaOverlay.minimumDuration else { return String(localized: "No room here · Move the playhead") }
        return String(localized: "Starts at \(DurationText.editor(start)) · room until \(DurationText.editor(start + room))")
    }

    // MARK: - Adding

    /// Copies what was picked into the edit's media, in the order picked; one that can't be read is said and skipped, a cancel
    /// (the pill) stops there.
    func importPicks(_ items: [PhotosPickerItem]) async -> [ImportedMedia] {
        guard isReady, !isImportingMedia, !items.isEmpty else { return [] }
        isImportingMedia = true
        defer { isImportingMedia = false }
        var imported: [ImportedMedia] = []
        for item in items {
            do {
                imported.append(try await importPicked(item))
            } catch is CancellationError {
                break
            } catch {
                noteFailure(error, "importMedia")
                toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Can't add this file")))
            }
        }
        guard !isClosed else {
            EditMediaFiles.remove(Set(imported.map(\.fileName)))
            return []
        }
        importedFiles.formUnion(imported.map(\.fileName))
        return imported
    }

    /// Puts `picks` in as `mode` says, one after the other from where they start, in one undo step: each video for its part,
    /// a photo for three seconds, shortened or left out only as `run(of:as:)` said. Supports go in silent, each framed on a face
    /// when there is one; the main video too, the first time it's in a split screen.
    func add(_ picks: [MediaPick], as mode: MediaInsertMode) async {
        guard let layout = mode.layout, !picks.isEmpty else { return }
        let run = run(of: picks, as: mode)
        let unused = Set(picks.map(\.imported.fileName)).subtracting(run.placed.map { picks[$0.index].imported.fileName })
        guard !run.placed.isEmpty else {
            EditMediaFiles.remove(Set(picks.map(\.imported.fileName)))
            toast.show(String(localized: "No room · Move the playhead"))
            return
        }
        // Windows and full screens over the same moment: never more than the export draws at once.
        if layout != .split {
            let others = mediaBars.map(\.span)
            guard run.placed.allSatisfy({ LayerLanes.peak(of: others, within: $0.span) < MediaOverlay.simultaneousLimit }) else {
                EditMediaFiles.remove(Set(picks.map(\.imported.fileName)))
                toast.show(String(localized: "Max 3 photos or videos"))
                return
            }
        }
        var next = edit
        if layout == .split, next.splitScreen.layouts.isEmpty { next.splitScreen.setLayout(SplitLayout()) }
        let splitLayout = next.splitScreen.layout(id: nil)
        let areas = SplitPlacement.areas(splitLayout, in: frameShape)
        var layer = (next.media.map(\.stackOrder).max() ?? -1) + 1
        var added: [UUID] = []
        for placed in run.placed {
            let pick = picks[placed.index]
            importedFiles.insert(pick.imported.fileName)
            var media = MediaOverlay(
                kind: pick.imported.kind, fileName: pick.imported.fileName, aspect: pick.imported.aspect,
                mediaDuration: pick.imported.duration, span: placed.span
            )
            media.followsCuts = true
            media.layout = layout
            media.mediaStart = pick.isVideo && pick.start > 0.000_1 ? pick.start : nil
            media.hasSound = pick.isVideo ? pick.imported.hasSound : nil
            media.layer = layer
            layer += 1
            if layout == .split {
                media.splitLayoutID = splitLayout.id
                media.areaFraming = await framing(of: pick, in: areas.support.size)
            }
            next.media.append(media)
            next.layMedia(at: next.media.count - 1, over: placed.span)
            added.append(media.id)
        }
        if layout == .split, let first = run.placed.first {
            await frameMainVideo(in: &next, at: first.span.start, area: areas.main.size)
        }
        guard !isClosed else { return }
        EditMediaFiles.remove(unused)
        commit(EditSnapshot(next))
        selectedArea = .support
        if let firstID = added.first { selection = .media(firstID) }
        player.pause()
        player.seek(to: run.placed[0].span.start)
        sayUndoable(addedMessage(picks: run.placed.map { picks[$0.index] }, run: run, mode: mode))
    }

    /// "3 videos added to the split screen · muted", "Photo added at 00:07.0"…
    private func addedMessage(picks: [MediaPick], run: MediaRun, mode: MediaInsertMode) -> String {
        let place = DurationText.editor(run.placed.first?.span.start ?? 0)
        let videos = picks.filter(\.isVideo).count
        var message: String
        if mode == .split {
            if picks.count > 1 {
                message = String(localized: "\(picks.count) added to the split screen from \(place)")
            } else if videos == 1 {
                message = String(localized: "Video added to the split screen at \(place)")
            } else {
                message = String(localized: "Photo added to the split screen at \(place)")
            }
        } else {
            message = picks.count == 1
                ? (videos == 1 ? String(localized: "Video added at \(place)") : String(localized: "Photo added at \(place)"))
                : String(localized: "\(picks.count) added over the video from \(place)")
        }
        // Videos go in silent: said, so the sound is never a surprise (the panel's Sound turns it up).
        if picks.contains(where: { $0.isVideo && $0.imported.hasSound }) { message += " · " + String(localized: "muted") }
        if run.leftOut > 0 { message += " · " + String(localized: "\(run.leftOut) didn’t fit") }
        return message
    }

    /// The edit's frame, for the areas' shapes (only the proportions count).
    var frameShape: CGSize {
        let aspect = max(0.1, edit.aspect.widthOverHeight)
        return CGSize(width: 1080, height: (1080 / aspect).rounded())
    }

    /// A pick framed in an area of `area` size: on the face in its first frame when there is one, else its middle.
    private func framing(of pick: MediaPick, in area: CGSize) async -> AreaFraming {
        let url = EditMediaFiles.url(for: pick.imported.fileName)
        guard let found = await faces.face(in: url, isVideo: pick.isVideo, at: pick.start + 0.2) else { return AreaFraming() }
        return SplitPlacement.framing(showing: found.box, content: found.size, area: area)
    }

    /// The main video's recording playing at `time` gets a framing for its area, on its face, unless it has one already (one the
    /// creator set is never moved).
    private func frameMainVideo(in edit: inout TakeEdit, at time: TimeInterval, area: CGSize) async {
        let timeline = edit.timeline
        let segment = timeline.segments[timeline.segmentIndex(atEdited: time)]
        guard !edit.splitScreen.hasFraming(for: segment.sourceID) else { return }
        let url = segment.sourceID.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
        guard let found = await faces.face(in: url, isVideo: true, at: timeline.sourceTime(forEdited: time)) else { return }
        edit.splitScreen.setFraming(SplitPlacement.framing(showing: found.box, content: found.size, area: area), for: segment.sourceID)
    }

    // MARK: - The layout

    /// The split screen's layout (the whole video's, for now).
    var splitLayout: SplitLayout { edit.splitScreen.layout(id: nil) }

    /// Changes the layout as one undo step (a drag of the seam is one, `beginChange`).
    func changeSplitLayout(_ change: (inout SplitLayout) -> Void) {
        var layout = splitLayout
        change(&layout)
        guard layout != splitLayout else { return }
        changeEdit { $0.splitScreen.setLayout(layout) }
    }

    /// Swaps the two contents' places; their sizes, sounds, parts and timing stay with them.
    func swapSplit() {
        changeSplitLayout { $0 = $0.swapped }
    }

    /// The support showing at the playhead, if any.
    var supportAtPlayhead: MediaOverlay? {
        let time = player.currentTime
        return edit.placedMedia(in: edit.timeline).first { entry in
            entry.media.layout == .split && entry.pieces.contains { $0.edited.start - 0.000_1 <= time && time < $0.edited.end }
        }?.media
    }

    /// A tap on an area of the split screen on the preview: its support is picked, with that area.
    func pickArea(_ area: SplitArea, of id: UUID) {
        if selection != .media(id) { selection = .media(id) }
        if selectedArea != area { Haptics.selection() }
        selectedArea = area
    }

    /// The seam dragged to `share` (the first area's share of the frame): the nearest of 40, 50 and 60%, the larger part going to
    /// whichever content is on that side. A drag is one undo step (`beginChange`).
    func dragSeam(toShare share: Double) {
        let layout = splitLayout
        let nearest = [0.4, 0.5, 0.6].min { abs($0 - share) < abs($1 - share) } ?? 0.5
        guard abs(nearest - layout.firstShare) > 0.001 else { return }
        Haptics.snap()
        changeSplitLayout { layout in
            if nearest == 0.5 {
                layout.ratio = .even
            } else {
                layout.ratio = .sixtyForty
                layout.larger = nearest > 0.5 ? layout.first : layout.first.other
            }
        }
    }

    /// The picture an area shows at the playhead, upright, for the copy that follows a finger: the support's file at its second,
    /// or the main video's recording at its moment.
    func areaPictureSource(_ area: SplitArea, of support: MediaOverlay) -> (url: URL, isVideo: Bool, time: TimeInterval)? {
        let time = player.currentTime
        switch area {
        case .support:
            let fileTime = support.kind == .video ? (support.fileTime(at: time, in: edit.timeline) ?? support.startInFile) : 0
            return (EditMediaFiles.url(for: support.fileName), support.kind == .video, fileTime)
        case .main:
            let timeline = edit.timeline
            let segment = timeline.segments[timeline.segmentIndex(atEdited: time)]
            let url = segment.sourceID.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
            return (url, true, timeline.sourceTime(forEdited: time))
        }
    }

    /// The split screen panel's tab: Layout unless another of its own is picked.
    var splitTab: EditorPanelTab {
        EditorPanelTab.splitScreen.contains(panelTab) ? panelTab : .layout
    }

    /// Shows the photo or video `id` another way (Split screen, Window, Full screen), keeping everything set on it, so going back
    /// finds it as it was. Into the split screen only where no other support shows (one at a time); the first time, framed on
    /// its face.
    func setMediaLayout(_ id: UUID, _ layout: MediaLayout) async {
        guard let index = edit.media.firstIndex(where: { $0.id == id }), edit.media[index].layout != layout,
              let span = mediaBars.first(where: { $0.id == id })?.span else { return }
        if layout == .split, supportSpans.contains(where: { $0.id != id && $0.span.overlaps(span) }) {
            toast.show(String(localized: "Another support shows then · one at a time in the split screen"))
            return
        }
        var next = edit
        if layout == .split {
            if next.splitScreen.layouts.isEmpty { next.splitScreen.setLayout(SplitLayout()) }
            let areas = SplitPlacement.areas(next.splitScreen.layout(id: nil), in: frameShape)
            next.media[index].splitLayoutID = next.splitScreen.layouts.first?.id
            if next.media[index].areaFraming == nil {
                let media = next.media[index]
                let pick = MediaPick(ImportedMedia(kind: media.kind, fileName: media.fileName, aspect: media.aspect, duration: media.mediaDuration))
                next.media[index].areaFraming = await framing(of: pick, in: areas.support.size)
            }
            await frameMainVideo(in: &next, at: span.start, area: areas.main.size)
        }
        guard !isClosed, edit.media.contains(where: { $0.id == id }) else { return }
        next.media[index].layout = layout
        commit(EditSnapshot(next))
        if layout == .split { selectedArea = .support }
    }

    // MARK: - Each area's framing

    /// The recording the main video plays at the playhead (nil: the take): its framing is the one the main area edits.
    var mainRecordingAtPlayhead: UUID? {
        let timeline = edit.timeline
        return timeline.segments[timeline.segmentIndex(atEdited: player.currentTime)].sourceID
    }

    /// How a content sits in its area while the support `id` shows.
    func areaFraming(_ area: SplitArea, of id: UUID) -> AreaFraming {
        switch area {
        case .main: edit.splitScreen.framing(for: mainRecordingAtPlayhead)
        case .support: edit.media.first { $0.id == id }?.areaFraming ?? AreaFraming()
        }
    }

    /// Sets how a content sits in its area: the support's own, or the main video's recording at the playhead (every clip of
    /// it shows the same way). A gesture or a slider is one undo step (`beginChange`).
    func setAreaFraming(_ framing: AreaFraming, for area: SplitArea, of id: UUID) {
        switch area {
        case .main:
            let recording = mainRecordingAtPlayhead
            guard framing != edit.splitScreen.framing(for: recording) || !edit.splitScreen.hasFraming(for: recording) else { return }
            changeEdit(key: "areaFraming") { $0.splitScreen.setFraming(framing, for: recording) }
        case .support:
            guard framing != areaFraming(.support, of: id) else { return }
            updateMedia(id) { $0.areaFraming = framing }
        }
    }

    /// The picture's upright size for an area: the main video's recording, or the support's file (its proportions).
    func contentSize(_ area: SplitArea, of id: UUID) -> CGSize {
        switch area {
        case .main:
            return recordingSizes[mainRecordingAtPlayhead] ?? CGSize(width: 1000 * take.aspect.widthOverHeight, height: 1000)
        case .support:
            let aspect = edit.media.first { $0.id == id }?.aspect ?? 1
            return CGSize(width: 1000 * aspect, height: 1000)
        }
    }

    /// Reads the upright size of each recording the main video plays, once, for the main area's gestures.
    func loadRecordingSizes() async {
        var urls: [UUID?: URL] = [nil: videoURL]
        for source in edit.playedSources { urls[source.id] = EditMediaFiles.url(for: source.fileName) }
        for (id, url) in urls where recordingSizes[id] == nil {
            if let shape = await EditFraming.shape(of: url) { recordingSizes[id] = shape.uprightSize }
        }
    }

    // MARK: - Sound

    /// How loud the main video plays while the support `id` shows, 0 to 1 (1 leaves it as it is).
    func setMainVolume(_ id: UUID, _ volume: Double) {
        let clamped = min(max(volume, 0), 1)
        updateMedia(id) { $0.mainVolume = clamped < 0.999 ? clamped : nil }
    }

    /// "Mute all supports": every photo and video laid over the take silent, each keeping its own volume for when it's back.
    func setMutesAllMedia(_ mutes: Bool) {
        guard mutes != edit.splitScreen.mutesMedia else { return }
        changeEdit { $0.splitScreen.mutesMedia = mutes }
        sayUndoable(mutes ? String(localized: "Every support is muted") : String(localized: "Supports play their sound again"))
    }

    // MARK: - Cutting, closing a gap

    /// Split (the scissors) on a photo or video: two at the playhead, the second playing on from the same second of the file, so
    /// nothing in the video changes until one of them is moved, trimmed or replaced.
    func splitMedia(_ id: UUID) {
        guard let index = edit.media.firstIndex(where: { $0.id == id }),
              let span = edit.placedMedia(in: edit.timeline).first(where: { $0.media.id == id })?.span else { return }
        let time = player.currentTime
        guard time - span.start >= MediaOverlay.minimumDuration, span.end - time >= MediaOverlay.minimumDuration else {
            toast.show(String(localized: "Move the playhead inside it to split it"))
            return
        }
        let original = edit.media[index]
        var second = original
        second.id = UUID()
        if original.kind == .video, let fileTime = original.fileTime(at: time, in: edit.timeline) { second.mediaStart = fileTime }
        let offset = time - span.start
        second.keyframes = original.keyframes?.filter { $0.time >= offset }.map { frame in
            var moved = frame
            moved.time -= offset
            return moved
        }
        var next = edit
        next.media[index].keyframes = original.keyframes?.filter { $0.time <= offset }
        next.layMedia(at: index, over: TimeSpan(start: span.start, end: time))
        next.media.insert(second, at: index + 1)
        next.layMedia(at: index + 1, over: TimeSpan(start: time, end: span.end))
        commit(EditSnapshot(next))
        selection = .media(second.id)
        sayUndoable(String(localized: "Split at \(DurationText.editor(time))"))
    }

    /// The space between the support `id` and the one before it, in seconds; nil when it follows right on (or is the first).
    func gapBefore(_ id: UUID) -> TimeInterval? {
        let spans = supportSpans
        guard let position = spans.firstIndex(where: { $0.id == id }), position > 0 else { return nil }
        let gap = spans[position].span.start - spans[position - 1].span.end
        return gap > 0.01 ? gap : nil
    }

    /// "Close gap": the support `id` moves to start where the one before ends, keeping its length and its part, so the main
    /// video doesn't take the whole frame in between. The speech isn't touched.
    func closeGap(before id: UUID) {
        guard let gap = gapBefore(id), let index = edit.media.firstIndex(where: { $0.id == id }),
              let span = supportSpans.first(where: { $0.id == id })?.span else { return }
        var next = edit
        next.layMedia(at: index, over: TimeSpan(start: span.start - gap, end: span.end - gap))
        commit(EditSnapshot(next))
        sayUndoable(String(localized: "Moved \(DurationText.tenths(gap)) back to meet the one before · the speech didn’t change"))
    }

    /// Trims the start of the photo or video `id` to `start` (edited seconds), keeping what shows at every moment that stays: a
    /// video's part starts later (or earlier, as far as its file goes) with it.
    func trimMediaStart(_ id: UUID, to start: TimeInterval) {
        guard let index = edit.media.firstIndex(where: { $0.id == id }),
              let placed = edit.placedMedia(in: edit.timeline).first(where: { $0.media.id == id }) else { return }
        let media = edit.media[index]
        var from = start
        var fileStart = placed.pieces.first?.fileStart ?? media.startInFile
        if media.kind == .video {
            if from < placed.span.start {
                // Earlier only as far as the file has more before its part.
                from = max(from, placed.span.start - fileStart)
                fileStart -= placed.span.start - from
            } else {
                fileStart = media.fileTime(at: from, in: edit.timeline) ?? fileStart
            }
        }
        guard abs(from - placed.span.start) > 0.000_1 else { return }
        var next = edit
        if media.kind == .video { next.media[index].mediaStart = fileStart > 0.000_1 ? fileStart : nil }
        next.layMedia(at: index, over: TimeSpan(start: from, end: placed.span.end))
        commit(EditSnapshot(next))
    }

    /// Lays the photo or video `id` over `span` (edited seconds), keeping its part: a bar moved or stretched on the timeline.
    func layMedia(_ id: UUID, over span: TimeSpan) {
        guard let index = edit.media.firstIndex(where: { $0.id == id }) else { return }
        var next = edit
        next.layMedia(at: index, over: span)
        commit(EditSnapshot(next))
    }
}
