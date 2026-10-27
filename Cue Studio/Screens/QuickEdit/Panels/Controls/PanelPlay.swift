//
//  PanelPlay.swift
//  Cue Studio
//

import Foundation

/// ▶ "PREVIEW" in a panel's header, before expand and ✓, round like them with a small tag on its corner so it never reads as
/// the video's play button: plays what the panel changes on the video (a Motion or a text's effect coming in, a blurred area,
/// a zoom, a speed, a transition, the current caption line) and comes back, in reach whatever the panel is scrolled to. One
/// per panel, `edit.panel.preview`.
struct PanelPlay {
    let action: () -> Void

    /// What VoiceOver says.
    static var label: String { String(localized: "Preview") }
    /// The tag on its corner: one short word, in capitals (as the toolbar's "ALL").
    static var tag: String {
        String(inInterfaceLanguage: LocalizedStringResource("panel.preview.tag", defaultValue: "Preview")).uppercased(with: .current)
    }
    static let identifier = "edit.panel.preview"
}

extension PanelPlay {
    /// The picked text's, graphic's, photo's or video's way in, when something moves it in (its Motion, or a text's effect
    /// that moves).
    static func motion(_ overlays: OverlaysViewModel) -> PanelPlay? {
        overlays.canPreviewMotion ? PanelPlay(action: overlays.previewMotion) : nil
    }
}
