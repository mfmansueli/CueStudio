//
//  VideoCover.swift
//  Cue Studio
//

import Foundation

/// The cover (thumbnail) chosen for a take: a frame of it or a photo, with an optional title in a
/// creator style. Saved to Photos next to the exported video, ready to pick as the post's cover.
nonisolated struct VideoCover: Codable, Hashable, Sendable {
    var source: CoverSource
    var title = ""
    /// Vertical center of the title as a fraction of the frame, from the top.
    var titleY = 0.2
    var style: CreatorStyle = .bold
    /// The title's preset (Cue for covers made in the v10 editor); nil keeps `style`, as covers
    /// made before it.
    var preset: TypePreset?

    init(source: CoverSource, style: CreatorStyle = .bold, preset: TypePreset? = nil) {
        self.source = source
        self.style = style
        self.preset = preset
    }

    /// The title as a text overlay, set like a title in the cover's style.
    var titleOverlay: TextOverlay? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let span = TimeSpan(start: 0, end: 1)
        var overlay = if let preset {
            TextOverlay(role: .title, look: preset.look(for: .title), preset: preset, span: span)
        } else {
            TextOverlay(role: .title, style: style, span: span)
        }
        overlay.text = title
        overlay.size = min(overlay.size * 1.2, TextOverlay.sizeRange.upperBound)
        overlay.center = OverlayPoint(x: 0.5, y: titleY).clamped
        return overlay
    }
}
