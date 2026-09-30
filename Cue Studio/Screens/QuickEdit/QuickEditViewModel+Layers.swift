//
//  QuickEditViewModel+Layers.swift
//  Cue Studio
//

import Foundation

/// The tracks under Text, Media and Voice-over: one bar per item where it plays in the edit.
/// Dragging a bar moves it; dragging an end changes when it starts or stops (a voice-over only
/// moves). Photos and videos never overlap: each stays in the gap it's in. Positions are kept on
/// the recording (see `TextOverlay`), so the bars land where the finger left them.
extension QuickEditViewModel {
    var textBars: [LayerBar] {
        edit.texts.compactMap { text in
            guard let span = edit.timeline.editedSpan(forSource: text.span) else { return nil }
            let title = text.isEmpty ? text.role.label : text.displayText
            return LayerBar(id: text.id, kind: .text, span: span, title: title, isSelected: text.id == selectedTextID)
        }
    }

    var mediaBars: [LayerBar] {
        edit.editedMedia(in: edit.timeline).map { entry in
            let title = entry.media.kind == .photo ? String(localized: "Photo") : String(localized: "Video")
            return LayerBar(id: entry.media.id, kind: .media, span: entry.span, title: title, isSelected: entry.media.id == selectedMediaID)
        }
    }

    var voiceOverBars: [LayerBar] {
        edit.voiceOvers.enumerated().compactMap { index, clip in
            guard let span = clip.editedSpan(in: edit.timeline) else { return nil }
            return LayerBar(
                id: clip.id, kind: .voiceOver, span: span,
                title: String(localized: "Voice-over \(index + 1)"), isSelected: clip.id == reviewedVoiceOverID
            )
        }
    }

    /// Caption lines where they play, for the shared timeline.
    var captionBars: [LayerBar] {
        editedCaptionLines.map { line in
            LayerBar(
                id: line.id, kind: .caption, span: line.span,
                title: line.text.isEmpty ? String(localized: "Empty line") : line.text, isSelected: line.id == selectedCaptionID
            )
        }
    }

    /// Tapping a bar selects it (again: lets go). Picking one lets go of the others, so Delete
    /// always means the one shown as picked.
    func selectBar(_ bar: LayerBar) {
        let wasSelected = selectedLayer?.id == bar.id
        clearLayerSelection()
        guard !wasSelected else { return }
        clearStripSelection()
        switch bar.kind {
        case .text: selectText(bar.id)
        case .caption:
            selectedCaptionID = bar.id
            showCaption(bar.id)
        case .media: selectMedia(bar.id)
        case .voiceOver: reviewedVoiceOverID = bar.id
        }
    }

    /// The bar picked on the timeline: a text, a caption line, a photo or video, or a voice-over.
    var selectedLayer: LayerBar? {
        (textBars + captionBars + mediaBars + voiceOverBars).first(where: \.isSelected)
    }

    /// Lets go of whatever bar is picked.
    func clearLayerSelection() {
        selectedTextID = nil
        selectedCaptionID = nil
        selectedMediaID = nil
        reviewedVoiceOverID = nil
    }

    /// Deletes the picked bar (one undo step).
    func deleteSelectedLayer() {
        guard let bar = selectedLayer else { return }
        switch bar.kind {
        case .text: deleteText(bar.id)
        case .caption: deleteCaption(bar.id)
        case .media: deleteMedia(bar.id)
        case .voiceOver: deleteVoiceOver(bar.id)
        }
    }

    /// Opens the picked bar where it is edited: its sheet (text, caption line) or its tool.
    func openSelectedLayer() {
        guard let bar = selectedLayer else { return }
        switch bar.kind {
        case .text: editingTextID = bar.id
        case .caption: editingCaptionID = bar.id
        case .media:
            tool = .media
            selectedMediaID = bar.id
        case .voiceOver:
            tool = .voiceOver
            reviewedVoiceOverID = bar.id
        }
    }

    /// Moves a bar so it starts at `start` (edited seconds), keeping its length.
    func moveBar(_ bar: LayerBar, toStart start: TimeInterval) {
        let length = bar.span.duration
        let limits = room(for: bar)
        let from = min(max(start, limits.start), max(limits.start, limits.end - length))
        let span = TimeSpan(start: from, end: min(limits.end, from + length))
        place(bar, at: span)
    }

    /// Moves one end of a bar to `time` (edited seconds).
    func resizeBar(_ bar: LayerBar, edge: LayerEdge, to time: TimeInterval) {
        guard bar.canResize else { return }
        let limits = room(for: bar)
        let shortest = switch bar.kind {
        case .text: TextOverlay.minimumDuration
        case .caption: CaptionCue.minimumDuration
        case .media, .voiceOver: MediaOverlay.minimumDuration
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
        guard span.duration >= shortest - 0.000_1 else { return }
        place(bar, at: span)
    }

    // MARK: - Private

    /// Where a bar can go: the whole edit, or for media the gap between its neighbors.
    private func room(for bar: LayerBar) -> TimeSpan {
        let total = edit.editedDuration
        guard bar.kind == .media else { return TimeSpan(start: 0, end: total) }
        let others = mediaBars.filter { $0.id != bar.id }.map(\.span)
        let before = others.filter { $0.end <= bar.span.start + 0.001 }.map(\.end).max() ?? 0
        let after = others.filter { $0.start >= bar.span.end - 0.001 }.map(\.start).min() ?? total
        return TimeSpan(start: before, end: after)
    }

    private func longestLength(of bar: LayerBar) -> TimeInterval? {
        guard bar.kind == .media else { return nil }
        return edit.media.first { $0.id == bar.id }?.mediaDuration
    }

    private func place(_ bar: LayerBar, at span: TimeSpan) {
        let source = edit.timeline.sourceSpan(forEdited: span)
        switch bar.kind {
        case .text:
            updateText(bar.id) { $0.span = source }
        case .media:
            updateMedia(bar.id) { $0.span = source }
        case .caption:
            moveCaption(bar.id, to: source)
        case .voiceOver:
            change { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == bar.id }) else { return }
                snapshot.voiceOvers[index].anchor = source.start
            }
        }
    }
}
