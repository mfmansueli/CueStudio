//
//  QuickEditViewModel+ClipSettings.swift
//  Cue Studio
//

import Foundation

/// Speed, Zoom and Volume of the picked clip (or of the music or voice-over picked). Each change
/// shows live and is an undo step; a slider's quick moves are one.
extension QuickEditViewModel {
    /// The speeds Speed offers as one tap.
    static let quickSpeeds: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    /// How long Zoom plays the clip when a move is picked, to show it.
    static let zoomPreviewLength: TimeInterval = 2.5

    // MARK: - Speed

    /// Plays the picked clip at `speed` (0.25× to 4×).
    func setClipSpeed(_ speed: Double) {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
        var timeline = edit.timeline
        guard timeline.setSpeed((speed * 20).rounded() / 20, forSegmentAt: index) else { return }
        commit(timeline, key: "clip.speed.\(clip.id)")
    }

    /// "Keep voice pitch".
    func setKeepsPitch(_ keeps: Bool) {
        updateClip { $0.keepsPitch = keeps }
    }

    /// "Split at playhead to change one part": with one clip, Speed changes the whole video.
    func splitToChangeOnePart() {
        guard let clip = targetClip else { return }
        panel = nil
        selection = .clip(clip.id)
        splitClip()
    }

    // MARK: - Zoom

    /// A camera move on the picked clip; picking one plays the first seconds of the clip to show
    /// it, then the playhead comes back.
    func setClipZoom(_ zoom: SectionZoom?) {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
        updateClip { $0.zoom = zoom }
        guard zoom != nil else { return }
        let start = edit.timeline.editedStart(ofSegmentAt: index)
        let end = min(start + edit.timeline.segments[index].duration, start + Self.zoomPreviewLength)
        previewPart(start...end)
    }

    /// The zoom's strength, 0 to 100.
    func setZoomIntensity(_ intensity: Double) {
        updateClip(key: "clip.zoomAmount") { $0.zoomAmount = min(max(intensity, 0), 100) / 100 }
    }

    // MARK: - Volume

    /// The volume Volume works on, 0 to 2: the picked music or voice-over, else the clip.
    var targetVolume: Double {
        switch selection {
        case .music(let id): edit.music.first { $0.id == id }?.volume ?? 1
        case .voiceOver(let id): edit.voiceOvers.first { $0.id == id }?.volume ?? 1
        default: targetClip?.volume ?? 1
        }
    }

    func setTargetVolume(_ volume: Double) {
        let value = min(max((volume * 100).rounded() / 100, 0), 2)
        switch selection {
        case .music(let id):
            change(key: "music.volume.\(id)") { snapshot in
                guard var music = snapshot.music, let index = music.firstIndex(where: { $0.id == id }) else { return }
                music[index].volume = value
                snapshot.music = music
            }
        case .voiceOver(let id):
            change(key: "voiceOver.volume.\(id)") { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == id }) else { return }
                snapshot.voiceOvers[index].volume = value
            }
        default:
            updateClip(key: "clip.volume") { $0.volume = value }
        }
    }

    func setClipMuted(_ muted: Bool) {
        updateClip { $0.isMuted = muted }
    }

    // MARK: - Private

    /// Changes the picked clip (or the one under the playhead) as an undo step.
    private func updateClip(key: String? = nil, _ update: (inout EditSegment) -> Void) {
        guard var clip = targetClip else { return }
        update(&clip)
        var timeline = edit.timeline
        guard timeline.replaceSegment(clip), timeline != edit.timeline else { return }
        commit(timeline, key: key.map { "\($0).\(clip.id)" })
    }

    /// Plays `range` (edited seconds) once, then puts the playhead back where it was (or at
    /// `back`).
    func previewPart(_ range: ClosedRange<TimeInterval>, back: TimeInterval? = nil) {
        let back = back ?? player.currentTime
        previewTask?.cancel()
        player.pause()
        player.reviewedPart = range
        player.seek(to: range.lowerBound)
        player.play()
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(range.upperBound - range.lowerBound + 0.3))
            guard !Task.isCancelled, let self else { return }
            if player.reviewedPart == range { player.reviewedPart = nil }
            player.pause()
            player.seek(to: back)
        }
    }
}
