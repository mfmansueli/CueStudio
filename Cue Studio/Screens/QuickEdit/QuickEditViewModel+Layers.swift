//
//  QuickEditViewModel+Layers.swift
//  Cue Studio
//

import Foundation

/// The tracks under Text, Media, Voice-over and Music: one bar per item where it plays in the edit.
/// Dragging a bar moves it; dragging an end changes when it starts or stops (a voice-over's or a
/// music clip's start takes its recording along). Up to three photos or videos overlap. Positions are kept on the recording (see
/// `TextOverlay`), so the bars land where the finger left them; music is kept on the edit's own
/// seconds.
extension QuickEditViewModel {
    /// Caption lines where they play, for the shared timeline.
    var captionBars: [LayerBar] {
        captions.captionMap.instances.map { line, cueID in
            LayerBar(
                id: line.id, kind: .caption, span: line.span,
                title: line.text.isEmpty ? String(localized: "Empty line") : line.text, isSelected: cueID == selectedCaptionID
            )
        }
    }

    /// The bar picked on the timeline: a text, a caption line, a photo or video, a voice-over or
    /// music.
    var selectedLayer: LayerBar? {
        (textBars + captionBars + mediaBars + voiceOverBars + audio.musicBars).first(where: \.isSelected)
    }

    /// Moves a bar so it starts at `start` (edited seconds), keeping its length.
    func moveBar(_ bar: LayerBar, toStart start: TimeInterval) {
        guard bar.kind != .music else {
            audio.moveMusic(bar.id, toStart: start)
            return
        }
        let length = bar.span.duration
        let limits = room(for: bar)
        let from = min(max(start, limits.start), max(limits.start, limits.end - length))
        let span = TimeSpan(start: from, end: min(limits.end, from + length))
        guard fits(bar, at: span) else { return }
        place(bar, at: span)
    }

    /// Moves one end of a bar to `time` (edited seconds).
    func resizeBar(_ bar: LayerBar, edge: LayerEdge, to time: TimeInterval) {
        switch bar.kind {
        case .music:
            audio.resizeMusic(bar.id, edge: edge, to: time)
            return
        case .voiceOver:
            audio.resizeVoiceOver(bar.id, edge: edge, to: time)
            return
        default: break
        }
        let limits = room(for: bar)
        let shortest = switch bar.kind {
        case .text: TextOverlay.minimumDuration
        case .caption: CaptionCue.minimumDuration
        case .media, .voiceOver: MediaOverlay.minimumDuration
        case .music: MusicClip.minimumDuration
        }
        var span = bar.span
        switch edge {
        case .start:
            span.start = min(max(time, limits.start), span.end - shortest)
            if let longest = longestLength(of: bar) { span.start = max(span.start, span.end - longest) }
        case .end:
            span.end = max(min(time, limits.end), span.start + shortest)
            if let longest = longestLength(of: bar) { span.end = min(span.end, span.start + longest) }
        }
        guard span.duration >= shortest - 0.000_1, fits(bar, at: span) else { return }
        place(bar, at: span)
    }

    // MARK: - Private

    /// Where a bar can go: the whole edit; a caption line only up to its neighbors, so lines never
    /// overlap.
    private func room(for bar: LayerBar) -> TimeSpan {
        let whole = TimeSpan(start: 0, end: edit.editedDuration)
        guard bar.kind == .caption else { return whole }
        let lines = captions.editedCaptionLines
        guard let index = lines.firstIndex(where: { $0.id == bar.id }) else { return whole }
        let floor = index > 0 ? lines[index - 1].end : 0
        let ceiling = index + 1 < lines.count ? lines[index + 1].start : edit.editedDuration
        return TimeSpan(start: floor, end: max(floor, ceiling))
    }

    /// Photos and videos can overlap, up to `MediaOverlay.simultaneousLimit` at a time; a move or a
    /// stretch past that stays where it was.
    private func fits(_ bar: LayerBar, at span: TimeSpan) -> Bool {
        guard bar.kind == .media else { return true }
        let others = mediaBars.filter { $0.id != bar.id }.map(\.span)
        return LayerLanes.peak(of: others, within: span) < MediaOverlay.simultaneousLimit
    }

    private func longestLength(of bar: LayerBar) -> TimeInterval? {
        guard bar.kind == .media else { return nil }
        return edit.media.first { $0.id == bar.id }.flatMap { $0.mediaDuration == nil ? nil : $0.longestDuration }
    }

    /// Pins a bar to where it was dropped: to the take's seconds, or in an arranged edit to the
    /// section it now starts on.
    private func place(_ bar: LayerBar, at span: TimeSpan) {
        let pinned = edit.pin(span)
        switch bar.kind {
        case .text:
            overlays.updateText(bar.id) { text in
                text.span = pinned.span
                text.clipAnchor = pinned.anchor
            }
        case .media:
            overlays.updateMedia(bar.id) { item in
                item.span = pinned.span
                item.clipAnchor = pinned.anchor
            }
        case .caption:
            // A line stays with its recording: only its time on it changes, and only over a clip of that recording.
            let cueID = captions.captionCueID(forLine: bar.id)
            let target = edit.timeline.anchoredSpan(forEdited: span)
            guard target.anchor.sourceID == edit.captions.first(where: { $0.id == cueID })?.sourceID else {
                toast.show(String(localized: "A line stays on its own clip"))
                return
            }
            captions.moveCaption(cueID, to: target.span)
        case .voiceOver:
            change { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == bar.id }) else { return }
                snapshot.voiceOvers[index].anchor = pinned.span.start
                snapshot.voiceOvers[index].clipAnchor = pinned.anchor
            }
        case .music:
            audio.moveMusic(bar.id, toStart: span.start)
        }
    }

    /// Starts or Ends −/+: the picked text (or photo or video) a tenth earlier or later.
    func nudgeLayerEdge(_ edge: LayerEdge, by seconds: TimeInterval) {
        guard let bar = selectedLayer, bar.kind == .text || bar.kind == .media else { return }
        resizeBar(bar, edge: edge, to: (edge == .start ? bar.span.start : bar.span.end) + seconds)
    }
}
