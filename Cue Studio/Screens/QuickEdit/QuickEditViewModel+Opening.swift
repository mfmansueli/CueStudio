//
//  QuickEditViewModel+Opening.swift
//  Cue Studio
//

import Foundation

/// The editor opening on one tool (a notification's "Try it"): its panel or sheet, nothing more. Every tool waits for the creator there:
/// Clean Up listens only because its panel opened at their choice, captions are made from "Generate", a translation needs a language, a
/// voice-over starts with its button, a photo needs picking, Skin starts at zero.
extension QuickEditViewModel {
    func open(_ tool: EditorTool) {
        guard isReady else { return }
        selection = nil
        toolMenu = nil
        switch tool {
        case .cleanUp:
            panel = .pauses
        case .autoCaptions:
            openCaptions()
        case .captionTranslation:
            openCaptions()
            if !edit.captions.isEmpty { captions.showsTranslation = true }
        case .studioVoice:
            panel = .voice
        case .skinSmoothing:
            // Skin on the whole video, on its smoothing: nothing applied, no preset picked.
            look.lookScopeIsClip = false
            look.skinOpensOn = .smoothing
            panel = .skin
        case .background:
            look.lookScopeIsClip = false
            panel = .background
        case .cover:
            cover.openCoverStudio()
        case .media:
            overlays.mediaInsertMode = overlays.lastOverlayMode
            sheet = .media
        case .voiceOver:
            panel = .voiceOver
        }
    }
}
