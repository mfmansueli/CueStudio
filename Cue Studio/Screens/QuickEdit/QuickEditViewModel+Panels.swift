//
//  QuickEditViewModel+Panels.swift
//  Cue Studio
//

import Foundation

/// The panels' headers: the title, and the subtitle that says what the panel changes ("This
/// clip", "Whole video", "Applies to all 8 lines", "Only this title changes").
extension QuickEditViewModel {
    /// ✓: applies (everything already shows live) and closes the panel.
    func closePanel() {
        player.pause()
        panel = nil
    }

    /// Space plays and pauses, except while a panel with a text field is open.
    var acceptsSpaceToPlay: Bool {
        guard sheet == nil else { return false }
        switch panel {
        case .textStyle?, .captions?: return false
        default: return true
        }
    }

    func panelTitle(_ panel: EditorPanel) -> String {
        if panel == .textStyle, let text = selectedText { return text.graphic?.kind.label ?? text.role.label }
        return panel.title
    }

    func panelSubtitle(_ panel: EditorPanel) -> String {
        switch panel {
        case .speed, .zoom, .volume, .stabilize: clipSubtitle(panel)
        case .voice: voiceScopeLabel
        case .adjust, .filters, .background: lookSubtitle(for: panel)
        case .pauses: String(localized: "Marked in yellow on the timeline")
        case .crop: String(localized: "Whole video · format for where you post")
        case .captions, .autoCaptions, .captionStyle: captionSubtitle(panel)
        case .textStyle: textStyleSubtitle
        case .voiceOver: String(localized: "Records from the playhead · the video plays muted")
        case .beats: beatsSubtitle
        case .media: String(localized: "On top of the video")
        case .transition: transitionSubtitle
        case .smart: String(localized: "Quick fixes, made on your iPhone")
        }
    }

    private func clipSubtitle(_ panel: EditorPanel) -> String {
        switch panel {
        case .speed:
            let clip = targetClip
            let from = DurationText.editor(clip?.sourceLength ?? 0)
            let to = DurationText.editor(clip?.duration ?? 0)
            return String(localized: "\(clipScope) · \(from) → \(to)")
        case .zoom: return String(localized: "\(clipScope) · camera move while it plays")
        case .stabilize: return String(localized: "\(clipScope) · steadies the camera’s shake")
        default:
            switch selection {
            case .music: return String(localized: "Music · under your voice")
            case .voiceOver: return String(localized: "Voice-over")
            default: return clipScope
            }
        }
    }

    /// Which clip a clip panel changes: "This clip" while the video is one clip, else "Clip 2 of 3", so the creator always knows
    /// where the change lands.
    var clipScope: String {
        let segments = edit.timeline.segments
        guard segments.count > 1, let id = targetClip?.id, let index = segments.firstIndex(where: { $0.id == id }) else {
            return String(localized: "This clip")
        }
        return String(localized: "Clip \(index + 1) of \(segments.count)")
    }

    private func captionSubtitle(_ panel: EditorPanel) -> String {
        switch panel {
        case .autoCaptions: return String(localized: "Cue drafts the lines. Fix any word.")
        case .captionStyle: return String(localized: "Applies to all \(editedCaptionLines.count) lines")
        default:
            guard edit.showsCaptions else { return String(localized: "Hidden in the video") }
            return String(localized: "\(editedCaptionLines.count) lines · tap one to jump there")
        }
    }

    /// What the tab on show changes: the look on the scope (Presets, Font, Color), or the picked text's
    /// motion and timing whatever the scope (Motion).
    private var textStyleSubtitle: String {
        // A graphic (arrow, circle, tag) has its own panel and is always changed alone.
        if selectedText?.graphic != nil { return String(localized: "Only this graphic changes") }
        guard textStyleTabChangesLook else { return String(localized: "Motion and timing change only this text") }
        switch textStyleScope {
        case .selected, .allCaptions:
            switch selectedText?.role ?? .title {
            case .title: return String(localized: "Only this title changes")
            case .subtitle: return String(localized: "Only this subtitle changes")
            case .hook: return String(localized: "Only this hook changes")
            case .callout: return String(localized: "Only this callout changes")
            }
        case .allTexts: return String(localized: "All \(edit.texts.count) texts change together")
        }
    }

    private var transitionSubtitle: String {
        guard let index = selectedJoinIndex else { return "" }
        return String(localized: "Cut at \(DurationText.editor(edit.timeline.editedStart(ofSegmentAt: index)))")
    }

    /// The clip a clip panel works on: the picked one, else the one under the playhead.
    var targetClip: EditSegment? {
        if let id = selection?.clipID, let segment = edit.timeline.segment(id: id) { return segment }
        let segments = edit.timeline.segments
        return segments.indices.contains(clipIndexAtPlayhead) ? segments[clipIndexAtPlayhead] : segments.first
    }
}
