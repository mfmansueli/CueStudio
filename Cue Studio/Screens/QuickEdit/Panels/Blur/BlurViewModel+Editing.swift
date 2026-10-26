//
//  BlurViewModel+Editing.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Changing a Blur area: its style, shape, strength, soft edge and the solid bar's color; where it is (a drag on the preview
/// puts it there at the playhead when it moves, everywhere when it stands still; a resize changes its size throughout); how
/// long (its ends on the timeline, "End here"); what's left unchecked ("Go there", "It's right", Review); and deleting it,
/// which takes nothing else with it. Every change is an undo step; a drag or a slider is one.
extension BlurViewModel {
    /// The picked area's stretch left unchecked that the panel talks about: the one under the playhead, else the first.
    var focusedUnchecked: TimeSpan? {
        guard let region = selectedBlur else { return nil }
        let open = region.openUnchecked
        if let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline),
           let under = open.first(where: { $0.start - 0.000_1 <= here && here < $0.end }) {
            return under
        }
        return open.first
    }

    /// Where `stretch` (seconds of the picked area's footage) first shows in the edit, as edited seconds; nil when it doesn't.
    func editedSpan(ofFootage stretch: TimeSpan) -> TimeSpan? {
        guard var region = selectedBlur else { return nil }
        region.span = stretch
        return edit.editedSpans(of: region, in: edit.timeline).first
    }

    /// Whether the playhead is in a stretch of the picked area left unchecked.
    var playheadIsUnchecked: Bool {
        guard let region = selectedBlur, let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline) else { return false }
        return region.openUnchecked.contains { $0.start - 0.000_1 <= here && here < $0.end }
    }

    // MARK: - Look

    func update(_ id: UUID, key: String? = nil, _ change: (inout BlurRegion) -> Void) {
        self.change(key: key) { snapshot in
            guard var regions = snapshot.blurRegions, let index = regions.firstIndex(where: { $0.id == id }) else { return }
            change(&regions[index])
            snapshot.blurRegions = regions
        }
    }

    func setStyle(_ style: BlurStyle) {
        guard let region = selectedBlur, region.style != style else { return }
        Haptics.selection()
        update(region.id) { $0.style = style }
    }

    func setShape(_ shape: BlurShape) {
        guard let region = selectedBlur, region.shape != shape else { return }
        Haptics.selection()
        update(region.id) { $0.shape = shape }
    }

    func setStrength(_ strength: Double) {
        guard let region = selectedBlur else { return }
        update(region.id, key: "blurStrength") { $0.strength = min(max(strength, 0), 1) }
    }

    func setFeather(_ feather: Double) {
        guard let region = selectedBlur else { return }
        update(region.id, key: "blurFeather") { $0.feather = min(max(feather, 0), 1) }
    }

    func setColor(_ color: OverlayColor) {
        guard let region = selectedBlur, region.color != color else { return }
        update(region.id) { $0.color = color }
    }

    // MARK: - Where it is

    /// The picked area put at `box` (its footage's upright picture) at the playhead: where it moves, a keyframe of the
    /// creator's there (following again never moves it); where it stands still, its one place.
    func place(_ box: NormalizedBox) {
        guard let region = selectedBlur else { return }
        guard region.moves else {
            update(region.id) { $0.box = box }
            return
        }
        guard let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline) else { return }
        update(region.id) { area in
            area.keyframes.removeAll { abs($0.time - here) < BlurFollowing.frame }
            area.keyframes.append(BlurKeyframe(time: here, box: box, isSet: true))
            area.keyframes.sort { $0.time < $1.time }
        }
    }

    /// The picked area `width` × `height` times as big, all along its path, each box around its own middle.
    func resize(width: Double, height: Double) {
        guard let region = selectedBlur, width.isFinite, height.isFinite, width > 0, height > 0 else { return }
        func scaled(_ box: NormalizedBox) -> NormalizedBox {
            NormalizedBox(center: box.center, width: max(0.02, box.width * width), height: max(0.02, box.height * height))
        }
        update(region.id) { area in
            area.box = scaled(area.box)
            area.keyframes = area.keyframes.map { BlurKeyframe(time: $0.time, box: scaled($0.box), isSet: $0.isSet) }
        }
    }

    /// VoiceOver: the picked area a step over, at the playhead (shares of its footage's picture).
    func nudge(x: Double, y: Double) {
        guard let region = selectedBlur else { return }
        let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline) ?? region.span.start
        let box = region.box(at: here)
        place(NormalizedBox(center: CGPoint(x: box.midX + x, y: box.midY + y), width: box.width, height: box.height))
    }

    // MARK: - How long

    /// "End here": the picked area stops at the playhead (its unchecked tail with it).
    func endHere() {
        guard let region = selectedBlur, let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline),
              here > region.span.start + BlurRegion.shortest, here < region.span.end else {
            toast.show(String(localized: "Move the playhead inside the area first"), kind: .problem)
            return
        }
        update(region.id) { $0.span.end = here }
        sayUndoable(String(localized: "Ends at \(DurationText.editor(player.currentTime))"))
    }

    /// One end of the bar `instance` (edited seconds, one showing of the area) dragged to `time`: the area's own start or end
    /// moves to the footage shown there (read backwards on a reversed clip), never past the clip it shows in. What it gains
    /// past what was followed is marked unchecked.
    func resizeBar(_ id: UUID, instance: TimeSpan, edge: LayerEdge, to time: TimeInterval) {
        guard let region = edit.blurRegions.first(where: { $0.id == id }), !edit.isOnPhoto(region) else { return }
        let timeline = edit.timeline
        let middle = (instance.start + instance.end) / 2
        // The clip (or piece of media) this showing is in: the end stays inside it.
        let bounds: TimeSpan
        if region.target.isMedia {
            bounds = edit.media(of: region)?.pieces(in: timeline).map(\.edited).first { $0.start - 0.000_1 <= middle && middle <= $0.end + 0.000_1 } ?? instance
        } else {
            let index = timeline.segmentIndex(atEdited: middle)
            let start = timeline.editedStart(ofSegmentAt: index)
            bounds = TimeSpan(start: start, end: start + timeline.segments[index].duration)
        }
        let clamped = min(max(time, bounds.start), max(bounds.start, bounds.end - 0.000_1))
        guard let footage = edit.footageTime(of: region.target, at: clamped, in: timeline),
              let first = edit.footageTime(of: region.target, at: instance.start, in: timeline),
              let last = edit.footageTime(of: region.target, at: max(instance.start, instance.end - 0.000_1), in: timeline) else { return }
        // A reversed clip shows the footage backwards: its left end is the area's end.
        let rising = last >= first
        let movesStart = (edge == .start) == rising
        var span = region.span
        if movesStart {
            span.start = min(max(0, footage), span.end - BlurRegion.shortest)
        } else {
            span.end = max(footage, span.start + BlurRegion.shortest)
        }
        guard span != region.span else { return }
        update(id) { $0.setSpan(span) }
    }

    /// A clip an area covered to its edge was lengthened (its handle dragged out): the area grows with it, so what the clip
    /// shows now isn't left uncovered, and the part nothing tracked is marked (`BlurRegion.setSpan`). In the same undo step as
    /// the drag.
    func growWithClips(from previous: TakeEdit) {
        guard previous.timeline != edit.timeline, !edit.blurRegions.isEmpty else { return }
        var regions = edit.blurRegions
        for index in regions.indices where !regions[index].target.isMedia {
            let recording = regions[index].target.recordingID
            var span = regions[index].span
            for old in previous.timeline.segments where old.sourceID == recording {
                guard let now = edit.timeline.segment(id: old.id), now.sourceID == old.sourceID else { continue }
                if abs(old.sourceStart - span.start) < 0.05, now.sourceStart < old.sourceStart - 0.01 { span.start = now.sourceStart }
                if abs(old.sourceEnd - span.end) < 0.05, now.sourceEnd > old.sourceEnd + 0.01 { span.end = now.sourceEnd }
            }
            if span != regions[index].span { regions[index].setSpan(span) }
        }
        guard regions != edit.blurRegions else { return }
        changeEdit { $0.blurRegions = regions }
    }

    // MARK: - Unchecked

    /// "Go there": the playhead to the start of the stretch the panel talks about, paused, to look at it.
    func goToUnchecked() {
        guard let stretch = focusedUnchecked, let shown = editedSpan(ofFootage: stretch) else { return }
        player.pause()
        player.seek(to: min(shown.end, shown.start + 0.05))
    }

    /// "It's right": the stretch the panel talks about was looked at and the area covers its subject there.
    func markChecked() {
        guard let region = selectedBlur, let stretch = focusedUnchecked else { return }
        update(region.id) { $0.markChecked(stretch) }
        let left = edit.blurRegions.first { $0.id == region.id }?.openUnchecked.count ?? 0
        toast.show(left == 0 ? String(localized: "Checked · Covered the whole time") : String(localized: "Checked · \(left) left to check"))
    }

    /// Review: plays the stretch the panel talks about (or the area's first showing), then back to where it started.
    func review() {
        guard let region = selectedBlur else { return }
        let shown = focusedUnchecked.flatMap(editedSpan(ofFootage:)) ?? edit.editedSpans(of: region, in: edit.timeline).first
        guard let shown else { return }
        previewPart(shown.start...shown.end, back: shown.start)
    }

    // MARK: - Deleting

    /// Takes the area off; nothing else in the edit changes.
    func delete(_ id: UUID) {
        guard edit.blurRegions.contains(where: { $0.id == id }) else { return }
        if following?.id == id { cancelFollowing() }
        change { snapshot in
            snapshot.blurRegions?.removeAll { $0.id == id }
        }
        if selectedBlurID == id {
            selection = nil
            panel = nil
        }
        sayUndoable(String(localized: "Blur area deleted"))
    }
}
