//
//  LookViewModel+ClipScope.swift
//  Cue Studio
//

import Foundation

/// Adjust, Skin, Filters and Background at two scopes: the whole take, and one clip. Opened from the main
/// toolbar they change the take (the base every clip plays with); opened from a picked clip they
/// change that clip only, as overrides (`ClipLook`) that the take's values show through wherever
/// the clip doesn't set its own. The panels, the sliders and the rendering are the same for both:
/// only where a change is written differs. Every change is an undo step (a clip's overrides live in
/// the timeline's clips, which undo already keeps).
extension LookViewModel {
    /// The clip Adjust, Skin, Filters or Background is changing, or nil when they change the whole take.
    var lookClip: EditSegment? {
        guard lookScopeIsClip, let id = selection?.clipID else { return nil }
        return edit.timeline.segment(id: id)
    }

    /// The light, color, skin and filter the panels show: the clip's (over the take's) or the take's.
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

    /// The look tool the open panel is.
    var openLookTool: EditorLookTool? {
        panel.flatMap(EditorLookTool.init(panel:))
    }

    /// How many clips set their own value for what `tool` changes, so a change to the whole video doesn't reach them.
    func clipsKeepingTheirOwn(for tool: EditorLookTool) -> Int {
        edit.timeline.segments.count(where: { clip in clip.look.map { tool.isOwn(in: $0) } ?? false })
    }

    /// "N clips keep their own · Use this on all", in the whole video's Adjust, Skin, Filters or Background: how many, for the open
    /// panel's tool; zero while it changes one clip.
    var clipsKeepingTheirOwnInPanel: Int {
        guard lookClip == nil, let tool = openLookTool else { return 0 }
        return clipsKeepingTheirOwn(for: tool)
    }

    /// "Use this on all": every clip takes the whole video's value for what the open panel's tool changes (Skin, every part of
    /// Skin and nothing of Adjust; Filters, the filter and its amount), and keeps the rest of its own. A slider still held ends first, as its own
    /// step; this is one more, said with Undo. Only when asked.
    func useWholeVideosLookOnAllClips() {
        guard lookClip == nil, let tool = openLookTool, clipsKeepingTheirOwn(for: tool) > 0 else { return }
        endAllChanges()
        var timeline = edit.timeline
        for var clip in timeline.segments {
            guard var look = clip.look, tool.isOwn(in: look) else { continue }
            tool.clear(&look)
            clip.look = look.normalized
            timeline.replaceSegment(clip)
        }
        guard timeline != edit.timeline else { return }
        commit(timeline)
        Haptics.apply()
        sayUndoable(String(localized: "Every clip uses this now"))
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

    /// What an Adjust, Skin, Filters or Background panel says it changes.
    func lookSubtitle(for panel: EditorPanel) -> String {
        // Background says its scope and what is behind the creator; its scope's rule is a note inside the panel.
        if panel == .background { return backgroundSubtitle }
        if lookClip != nil { return String(localized: "\(clipScope) · the rest stays as it is") }
        // The clips that keep their own say so under the header, with "Use this on all".
        return String(localized: "Whole video")
    }
}
