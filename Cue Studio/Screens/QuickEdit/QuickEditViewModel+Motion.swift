//
//  QuickEditViewModel+Motion.swift
//  Cue Studio
//

import Foundation

/// Keyframes for the picked text or photo or video: add one at the playhead (it starts where the
/// item is now), take it away, go to the next or the one before, and set how it gets there, how big
/// and how opaque. Once an item has keyframes, moving or resizing it on the preview sets the one at
/// the playhead (adding it when there's none). Keyframe times count from the item's start, so moving
/// the item takes its motion along. Every change is an undo step; a slider is one.
extension QuickEditViewModel {
    /// What keyframes apply to.
    enum MotionItem: Equatable {
        case text(UUID)
        case media(UUID)
    }

    /// The picked text, else the picked photo or video.
    var motionItem: MotionItem? {
        if let id = selectedTextID { return .text(id) }
        if let id = selectedMediaID { return .media(id) }
        return nil
    }

    func keyframes(of item: MotionItem) -> [OverlayKeyframe] {
        switch item {
        case .text(let id): edit.texts.first { $0.id == id }?.keyframes ?? []
        case .media(let id): edit.media.first { $0.id == id }?.keyframes ?? []
        }
    }

    /// Where the item plays (edited seconds).
    func editedSpan(of item: MotionItem) -> TimeSpan? {
        switch item {
        case .text(let id): editedSpan(ofText: id)
        case .media(let id): mediaBars.first { $0.id == id }?.span
        }
    }

    /// Seconds into the item at the playhead; nil when it isn't showing.
    func localTime(of item: MotionItem) -> TimeInterval? {
        guard let span = editedSpan(of: item) else { return nil }
        let time = player.currentTime
        guard time >= span.start - 0.000_1, time <= span.end + 0.000_1 else { return nil }
        return min(max(0, time - span.start), span.duration)
    }

    /// The keyframe at the playhead (within a frame).
    func keyframeAtPlayhead(of item: MotionItem) -> OverlayKeyframe? {
        guard let local = localTime(of: item) else { return nil }
        return keyframes(of: item).first { abs($0.time - local) <= OverlayKeyframe.sameMoment }
    }

    /// Where the item is, how big and how opaque at the playhead.
    func motionState(of item: MotionItem) -> OverlayMotion.State {
        let base = OverlayMotion.State(center: baseCenter(of: item), scale: 1, opacity: 1)
        guard let local = localTime(of: item) else { return base }
        return OverlayMotion(keyframes(of: item)).state(at: local) ?? base
    }

    /// Adds a keyframe at the playhead where the item is now, or takes away the one there.
    func toggleKeyframe() {
        guard let item = motionItem, let local = localTime(of: item) else {
            toast.show(String(localized: "Move playhead onto it first"))
            return
        }
        player.pause()
        if let existing = keyframeAtPlayhead(of: item) {
            updateKeyframes(of: item) { $0.removeAll { $0.id == existing.id } }
            toast.show(String(localized: "Keyframe removed"))
            return
        }
        let state = motionState(of: item)
        let keyframe = OverlayKeyframe(time: local, center: state.center, scale: state.scale, opacity: state.opacity)
        updateKeyframes(of: item) { $0.append(keyframe) }
        toast.show(String(localized: "Keyframe added · Now drag"))
    }

    /// Goes to the next keyframe (or the one before).
    func jumpToKeyframe(forward: Bool) {
        guard let item = motionItem, let span = editedSpan(of: item) else { return }
        let local = player.currentTime - span.start
        let times = keyframes(of: item).map(\.time).sorted()
        let target = forward
            ? times.first { $0 > local + OverlayKeyframe.sameMoment }
            : times.last { $0 < local - OverlayKeyframe.sameMoment }
        guard let target else { return }
        player.pause()
        player.seek(to: min(span.end, span.start + target))
    }

    func setKeyframeEasing(_ easing: KeyframeEasing) {
        setAtPlayhead { $0.easing = easing }
    }

    func setKeyframeOpacity(_ opacity: Double) {
        setAtPlayhead { $0.opacity = min(max(opacity, 0), 1) }
    }

    func setKeyframeScale(_ scale: Double) {
        setAtPlayhead { $0.scale = min(max(scale, OverlayKeyframe.scaleRange.lowerBound), OverlayKeyframe.scaleRange.upperBound) }
    }

    /// A text dragged on the preview: its keyframe at the playhead when it moves, else its place.
    func moveText(_ id: UUID, to center: OverlayPoint) {
        guard edit.texts.first(where: { $0.id == id })?.keyframes.isEmpty == false else {
            customizeText(id, .position) { $0.center = center }
            return
        }
        setAtPlayhead(of: .text(id)) { $0.center = center }
    }

    /// A photo or video dragged on the preview: likewise.
    func moveMedia(_ id: UUID, to center: OverlayPoint) {
        guard edit.media.first(where: { $0.id == id })?.keyframes?.isEmpty == false else {
            updateMedia(id) { $0.center = center }
            return
        }
        setAtPlayhead(of: .media(id)) { $0.center = center }
    }

    /// A photo or video pinched on the preview by `factor`: its keyframe's scale when it moves,
    /// else its width.
    func resizeMedia(_ id: UUID, by factor: Double) {
        guard let media = edit.media.first(where: { $0.id == id }) else { return }
        guard media.keyframes?.isEmpty == false else {
            let width = min(max(media.width * factor, MediaOverlay.widthRange.lowerBound), MediaOverlay.widthRange.upperBound)
            updateMedia(id) { $0.width = width }
            return
        }
        let current = motionState(of: .media(id)).scale
        setAtPlayhead(of: .media(id)) {
            $0.scale = min(max(current * factor, OverlayKeyframe.scaleRange.lowerBound), OverlayKeyframe.scaleRange.upperBound)
        }
    }

    /// Where a bar's keyframes are (edited seconds from its start), for marks on its track.
    func keyframeOffsets(of bar: LayerBar) -> [TimeInterval] {
        switch bar.kind {
        case .text: keyframes(of: .text(bar.id)).map(\.time).filter { $0 <= bar.span.duration }
        case .media: keyframes(of: .media(bar.id)).map(\.time).filter { $0 <= bar.span.duration }
        case .caption, .voiceOver, .music: []
        }
    }

    // MARK: - Private

    private func baseCenter(of item: MotionItem) -> OverlayPoint {
        switch item {
        case .text(let id): edit.texts.first { $0.id == id }?.center ?? .center
        case .media(let id): edit.media.first { $0.id == id }?.center ?? .center
        }
    }

    /// Changes the keyframe at the playhead of the picked item, adding it first when there's none.
    private func setAtPlayhead(_ update: (inout OverlayKeyframe) -> Void) {
        guard let item = motionItem else { return }
        setAtPlayhead(of: item, update)
    }

    private func setAtPlayhead(of item: MotionItem, _ update: (inout OverlayKeyframe) -> Void) {
        guard let local = localTime(of: item) else { return }
        var keyframe = keyframeAtPlayhead(of: item) ?? {
            let state = motionState(of: item)
            return OverlayKeyframe(time: local, center: state.center, scale: state.scale, opacity: state.opacity)
        }()
        update(&keyframe)
        updateKeyframes(of: item) { keyframes in
            if let index = keyframes.firstIndex(where: { $0.id == keyframe.id }) {
                keyframes[index] = keyframe
            } else {
                keyframes.append(keyframe)
            }
        }
    }

    private func updateKeyframes(of item: MotionItem, _ update: (inout [OverlayKeyframe]) -> Void) {
        switch item {
        case .text(let id):
            updateText(id) { text in
                update(&text.keyframes)
                text.keyframes.sort { $0.time < $1.time }
            }
        case .media(let id):
            updateMedia(id) { media in
                var keyframes = media.keyframes ?? []
                update(&keyframes)
                media.keyframes = keyframes.isEmpty ? nil : keyframes.sorted { $0.time < $1.time }
            }
        }
    }
}
