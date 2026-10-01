//
//  QuickEditViewModel+Panels.swift
//  Cue Studio
//

import Foundation

/// The panels' headers: the title, and the subtitle that says what the panel changes ("This
/// clip", "Whole take", "Applies to all 8 lines", "Only this title changes").
extension QuickEditViewModel {
    /// ✓: applies (everything already shows live) and closes the panel.
    func closePanel() {
        player.pause()
        panel = nil
    }

    func panelTitle(_ panel: EditorPanel) -> String {
        if panel == .textStyle, let text = selectedText { return text.role.label }
        return panel.title
    }

    func panelSubtitle(_ panel: EditorPanel) -> String {
        switch panel {
        case .speed, .zoom, .volume: clipSubtitle(panel)
        case .voice, .adjust, .filters: String(localized: "Whole take")
        case .pauses: String(localized: "Marked in yellow on the timeline")
        case .crop: String(localized: "Format for where you post")
        case .background: String(localized: "Whole take · your recording stays untouched")
        case .cover: String(localized: "Shown before the video plays")
        case .captions, .autoCaptions, .captionStyle: captionSubtitle(panel)
        case .textStyle: textStyleSubtitle
        case .voiceOver: String(localized: "Records from the playhead · the video plays muted")
        case .media: String(localized: "On top of the video")
        case .transition: transitionSubtitle
        }
    }

    private func clipSubtitle(_ panel: EditorPanel) -> String {
        switch panel {
        case .speed:
            let clip = targetClip
            let from = DurationText.editor(clip?.sourceLength ?? 0)
            let to = DurationText.editor(clip?.duration ?? 0)
            return String(localized: "This clip · \(from) → \(to)")
        case .zoom: return String(localized: "This clip · camera move while it plays")
        default:
            switch selection {
            case .music: return String(localized: "Music · under your voice")
            case .voiceOver: return String(localized: "Voice-over")
            default: return String(localized: "This clip")
            }
        }
    }

    private func captionSubtitle(_ panel: EditorPanel) -> String {
        switch panel {
        case .autoCaptions: return String(localized: "Cue listens to your take and writes the lines")
        case .captionStyle: return String(localized: "Applies to all \(editedCaptionLines.count) lines")
        default:
            guard edit.showsCaptions else { return String(localized: "Hidden in the video") }
            return String(localized: "\(editedCaptionLines.count) lines · tap one to jump there")
        }
    }

    private var textStyleSubtitle: String {
        switch textStyleScope {
        case .selected:
            switch selectedText?.role ?? .title {
            case .title: return String(localized: "Only this title changes")
            case .subtitle: return String(localized: "Only this subtitle changes")
            case .hook: return String(localized: "Only this hook changes")
            case .callout: return String(localized: "Only this callout changes")
            }
        case .allTexts: return String(localized: "All \(edit.texts.count) texts change together")
        case .allCaptions, .textsAndCaptions: return String(localized: "All texts and captions change together")
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
