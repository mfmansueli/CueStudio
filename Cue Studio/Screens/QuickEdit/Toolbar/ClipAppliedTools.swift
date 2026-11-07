//
//  ClipAppliedTools.swift
//  Cue Studio
//

import Foundation

/// The picked clip's tools that changed it (owner, canvas 2 M2): a dot on each in the clip's bar, and VoiceOver hears "Changed
/// on this clip". It reads the clip as it is, so it follows another clip picked, Reset clip and Undo. Mute and Mirror are
/// switches, lit instead; the tools that change the whole video carry All, never the dot.
nonisolated enum ClipAppliedTools {
    static func ids(of clip: EditSegment, in segments: [EditSegment]) -> Set<String> {
        var ids: Set<String> = []
        func mark(_ changed: Bool, _ id: String) {
            if changed { ids.insert(id) }
        }
        mark(clip.changesSpeed, EditorToolbarTool.speed.id)
        mark(abs(clip.volume - 1) > 0.001 || clip.soundFadeIn > 0 || clip.soundFadeOut > 0, EditorToolbarTool.volume.id)
        mark(clip.zoom != nil, EditorToolbarTool.zoom.id)
        let look = clip.look
        mark(look?.overridesAdjustment == true, EditorLookTool.adjust.toolbarID(wholeVideo: false))
        mark(look?.overridesSkin == true, EditorLookTool.skin.toolbarID(wholeVideo: false))
        mark(look?.overridesFilter == true, EditorLookTool.filters.toolbarID(wholeVideo: false))
        mark(look?.background != nil, EditorLookTool.background.toolbarID(wholeVideo: false))
        mark(clip.crop != nil || clip.quarterTurns % 4 != 0, EditorToolbarTool.crop.id)
        mark(clip.stabilization != nil, EditorToolbarTool.stabilize.id)
        mark(clip.animationIn != nil || clip.animationOut != nil, EditorToolbarTool.animation.id)
        mark(clip.voiceEffect != nil, "voiceEffects")
        // Transition opens the cut after the clip (the last clip's, the one before it).
        if segments.count > 1, let index = segments.firstIndex(where: { $0.id == clip.id }) {
            mark(segments[min(index + 1, segments.count - 1)].transitionIn != .hardCut, "transition")
        }
        return ids
    }
}
