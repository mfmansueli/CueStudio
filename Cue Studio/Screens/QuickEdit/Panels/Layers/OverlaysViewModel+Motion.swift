//
//  OverlaysViewModel+Motion.swift
//  Cue Studio
//

import Foundation

/// Keyframes for the picked text or photo or video: add one at the playhead (it starts where the
/// item is now), take it away, go to the next or the one before, and set how it gets there, how big
/// and how opaque. Once an item has keyframes, moving or resizing it on the preview sets the one at
/// the playhead (adding it when there's none). Keyframe times count from the item's start, so moving
/// the item takes its motion along. Every change is an undo step; a slider is one.
extension OverlaysViewModel {
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
        let base = OverlayMotion.State(center: baseCenter(of: item), scale: 1, opacity: 1, rotation: baseRotation(of: item))
        guard let local = localTime(of: item) else { return base }
        let length = editedSpan(of: item)?.duration ?? 0
        return OverlayMotion(keyframes(of: item), animation: animation(of: item), length: length, base: base).state(at: local) ?? base
    }

    // MARK: - Ready-made motion

    /// The picked item's ready-made motion, if it has one.
    func animation(of item: MotionItem) -> OverlayAnimation? {
        switch item {
        case .text(let id): edit.texts.first { $0.id == id }?.animation
        case .media(let id): edit.media.first { $0.id == id }?.animation
        }
    }

    var selectedAnimation: OverlayAnimation? {
        motionItem.flatMap(animation(of:))
    }

    /// Picks a ready-made motion for the picked item (nil: none), keeping its duration and strength when it had one. One undo
    /// step; the keyframes stay as they are. The playhead goes to the item's start, to see it. On a text that wears an effect,
    /// one way in at a time: a Motion (or None) leaves the effect still, its finish kept, and its Animated tab says Still;
    /// "Effect's own" (`playEffectsOwnMotion`) gives it back.
    func setMotionPreset(_ preset: MotionPreset?) {
        guard let item = motionItem else { return }
        let current = animation(of: item)
        let next = preset.map { OverlayAnimation(preset: $0, duration: current?.duration ?? 0.5, intensity: current?.intensity ?? 0.5) }
        if case .text(let id) = item, edit.texts.first(where: { $0.id == id })?.effect != nil {
            customizeText(id, .effect) { text in
                text.animation = next
                text.effect?.motion = .still
            }
        } else {
            setAnimation(next, of: item)
        }
        if next != nil, let span = editedSpan(of: item) {
            player.pause()
            player.seek(to: span.start)
        }
        Haptics.selection()
    }

    /// Motion's "Effect's own": the picked text's effect plays its own way in and out again, as its card shows, with no Motion
    /// over it. One undo step; the playhead goes to the text's start, to see it.
    func playEffectsOwnMotion() {
        guard let text = selectedText, text.effect != nil else { return }
        customizeText(text.id, .effect) { text in
            text.animation = nil
            text.effect?.motion = .animated
        }
        if let span = editedSpan(ofText: text.id) {
            player.pause()
            player.seek(to: span.start)
        }
        Haptics.selection()
    }

    func setMotionDuration(_ duration: TimeInterval) {
        guard let item = motionItem, var animation = animation(of: item) else { return }
        animation.duration = min(max(duration, OverlayAnimation.durationRange.lowerBound), OverlayAnimation.durationRange.upperBound)
        setAnimation(animation, of: item, key: "motionDuration")
    }

    func setMotionIntensity(_ intensity: Double) {
        guard let item = motionItem, var animation = animation(of: item) else { return }
        animation.intensity = min(max(intensity, 0), 1)
        setAnimation(animation, of: item, key: "motionIntensity")
    }

    /// Something moves the picked item in (its Motion, or a text's effect that moves): "Preview" in its panel's header.
    var canPreviewMotion: Bool {
        guard let item = motionItem else { return false }
        return animation(of: item) != nil || (selectedTextID != nil && selectedText?.effect?.isAnimated == true)
    }

    /// "Preview": plays the picked item from its start, to see its motion, then the playhead goes back. A text's effect comes
    /// in as the video will show it, for as long as its way in lasts (or its own Motion, which plays instead).
    func previewMotion() {
        guard let item = motionItem, let span = editedSpan(of: item) else { return }
        let length: TimeInterval
        if selectedTextID != nil, let effect = selectedText?.effect {
            length = (animation(of: item)?.duration ?? effect.duration) + 0.9
        } else {
            length = max(1.2, (animation(of: item)?.duration ?? 0.5) * 2.5)
        }
        previewPart(span.start...min(span.end, span.start + length))
    }

    private func setAnimation(_ animation: OverlayAnimation?, of item: MotionItem, key: String? = nil) {
        switch item {
        case .text(let id):
            change(key: key) { snapshot in
                guard let index = snapshot.texts.firstIndex(where: { $0.id == id }) else { return }
                snapshot.texts[index].animation = animation
            }
        case .media(let id):
            change(key: key) { snapshot in
                guard let index = snapshot.media.firstIndex(where: { $0.id == id }) else { return }
                snapshot.media[index].animation = animation
            }
        }
    }

    /// Adds a keyframe at the playhead where the item is now, or takes away the one there.
    func toggleKeyframe() {
        guard let item = motionItem, let local = localTime(of: item) else {
            toast.show(String(localized: "Move playhead onto it first"), kind: .problem)
            return
        }
        player.pause()
        if let existing = keyframeAtPlayhead(of: item) {
            updateKeyframes(of: item) { $0.removeAll { $0.id == existing.id } }
            toast.show(String(localized: "Keyframe removed"))
            return
        }
        let keyframe = keyframeHere(of: item, at: local)
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

    // MARK: - Private

    private func baseCenter(of item: MotionItem) -> OverlayPoint {
        switch item {
        case .text(let id): edit.texts.first { $0.id == id }?.center ?? .center
        case .media(let id): edit.media.first { $0.id == id }?.center ?? .center
        }
    }

    /// A text's own turn; photos and videos don't turn.
    private func baseRotation(of item: MotionItem) -> Double {
        guard case .text(let id) = item else { return 0 }
        return edit.texts.first { $0.id == id }?.rotation ?? 0
    }

    /// A keyframe `local` seconds in, where the item is now (a text's turn included).
    private func keyframeHere(of item: MotionItem, at local: TimeInterval) -> OverlayKeyframe {
        let state = motionState(of: item)
        let turn: Double? = if case .text = item { state.rotation } else { nil }
        return OverlayKeyframe(time: local, center: state.center, scale: state.scale, opacity: state.opacity, mask: state.mask, rotation: turn)
    }

    /// Changes the keyframe at the playhead of the picked item, adding it first when there's none.
    /// Changes the item's keyframe at the playhead, adding it first (where the item is now) when there's none.
    func setAtPlayhead(of item: MotionItem, _ update: (inout OverlayKeyframe) -> Void) {
        guard let local = localTime(of: item) else { return }
        var keyframe = keyframeAtPlayhead(of: item) ?? keyframeHere(of: item, at: local)
        update(&keyframe)
        updateKeyframes(of: item) { keyframes in
            if let index = keyframes.firstIndex(where: { $0.id == keyframe.id }) {
                keyframes[index] = keyframe
            } else {
                keyframes.append(keyframe)
            }
        }
    }

    func updateKeyframes(of item: MotionItem, _ update: (inout [OverlayKeyframe]) -> Void) {
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
