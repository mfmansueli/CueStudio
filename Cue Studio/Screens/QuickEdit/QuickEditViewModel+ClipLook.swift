//
//  QuickEditViewModel+ClipLook.swift
//  Cue Studio
//

import Foundation

/// Adjust, Filters and Background at two scopes: the whole take, and one clip. Opened from the main
/// toolbar they change the take (the base every clip plays with); opened from a picked clip they
/// change that clip only, as overrides (`ClipLook`) that the take's values show through wherever
/// the clip doesn't set its own. The panels, the sliders and the rendering are the same for both:
/// only where a change is written differs. Every change is an undo step (a clip's overrides live in
/// the timeline's clips, which undo already keeps).
extension QuickEditViewModel {
    /// The clip Adjust, Filters or Background is changing, or nil when they change the whole take.
    var lookClip: EditSegment? {
        guard lookScopeIsClip, let id = selection?.clipID else { return nil }
        return edit.timeline.segment(id: id)
    }

    /// The light, color and filter the panels show: the clip's (over the take's) or the take's.
    var effectiveLook: LookSettings {
        lookClip.map { edit.lookSettings(for: $0) } ?? LookSettings(edit)
    }

    /// Writes `update` on the picked clip's overrides; an override left empty goes.
    func updateClipLook(key: String? = nil, _ update: (inout ClipLook) -> Void) {
        guard lookClip != nil else { return }
        updateClip(key: key) { clip in
            var look = clip.look ?? ClipLook()
            update(&look)
            clip.look = look.normalized
        }
    }

    /// Whether some clip sets its own value for what `panel` changes, so a change to the whole take
    /// doesn't reach it.
    func someClipKeepsItsOwn(for panel: EditorPanel) -> Bool {
        edit.timeline.segments.contains { clip in
            guard let look = clip.look else { return false }
            switch panel {
            case .adjust: return look.overridesAdjustment
            case .filters: return look.filter != nil || look.filterAmount != nil
            case .background: return look.background != nil
            default: return false
            }
        }
    }

    // MARK: - Following the picked clip

    /// Whether the open panel closes when what it works on is let go. A look panel opened from a
    /// clip follows the picked clip, so its scope never changes without the creator seeing it.
    func followsSelection(_ panel: EditorPanel) -> Bool {
        panel.followsSelection || (lookScopeIsClip && panel.hasClipScope)
    }

    func accepts(_ selection: EditorSelection, in panel: EditorPanel) -> Bool {
        if lookScopeIsClip, panel.hasClipScope { return selection.clipID != nil }
        return panel.accepts(selection)
    }

    // MARK: - Header

    /// What an Adjust, Filters or Background panel says it changes.
    func lookSubtitle(for panel: EditorPanel) -> String {
        if lookClip != nil { return String(localized: "This clip · the rest stays as it is") }
        if someClipKeepsItsOwn(for: panel) { return String(localized: "Whole take · some clips keep their own") }
        return panel == .background ? String(localized: "Whole take · your recording stays untouched") : String(localized: "Whole take")
    }
}
