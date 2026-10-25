//
//  EditorPart+Bars.swift
//  Cue Studio
//

import Foundation

/// What lies over the video and under it, where it plays in the edit: one bar per text, photo or video and voice-over, as the
/// tracks draw them and the tools read them (the picked one is marked). Caption lines and music have theirs in their parts.
extension EditorPart {
    var textBars: [LayerBar] {
        edit.texts.compactMap { text in
            guard let span = TakeEdit.editedSpan(text.span, anchor: text.clipAnchor, in: edit.timeline) else { return nil }
            let title = text.graphic.map { graphic in
                graphic.kind.hasText && !text.isEmpty ? "\(graphic.kind.label) · \(text.displayText)" : graphic.kind.label
            } ?? (text.isEmpty ? text.role.label : text.displayText)
            return LayerBar(
                id: text.id, kind: .text, span: span, title: title, isSelected: text.id == selectedTextID,
                keyframes: text.keyframes.map(\.time).filter { $0 <= span.duration }
            )
        }
    }

    var mediaBars: [LayerBar] {
        edit.editedMedia(in: edit.timeline).map { entry in
            let title = entry.media.kind == .photo ? String(localized: "Photo") : String(localized: "Video")
            return LayerBar(
                id: entry.media.id, kind: .media, span: entry.span, title: title, isSelected: entry.media.id == selectedMediaID,
                keyframes: (entry.media.keyframes ?? []).map(\.time).filter { $0 <= entry.span.duration }
            )
        }
    }

    /// Where the photos and videos that count in `MediaOverlay.simultaneousLimit` play: all but a still logo, and not `excluded`
    /// (the one being moved, stretched or replaced).
    func limitedMediaSpans(excluding excluded: UUID? = nil) -> [TimeSpan] {
        edit.editedMedia(in: edit.timeline).filter { !$0.media.isStaticLogo && $0.media.id != excluded }.map(\.span)
    }

    /// Whether `media` can show over `span` with no more than `MediaOverlay.simultaneousLimit` at once: always, for a still logo.
    func mediaFits(_ media: MediaOverlay, over span: TimeSpan) -> Bool {
        media.isStaticLogo || LayerLanes.peak(of: limitedMediaSpans(excluding: media.id), within: span) < MediaOverlay.simultaneousLimit
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
}
