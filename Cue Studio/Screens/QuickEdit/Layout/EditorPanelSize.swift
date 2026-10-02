//
//  EditorPanelSize.swift
//  Cue Studio
//

import CoreGraphics

/// The three heights a panel can have, each a share of the usable height within limits.
nonisolated enum EditorPanelSize: Equatable, Sendable {
    /// One or two controls: Speed, Zoom, Volume, Filters, Crop, Voice-over, Auto captions.
    case mini
    /// A list or several controls: Voice, Pauses, Captions, Adjust, Background, Cover.
    case medium
    /// Styling, with tabs: Text style, Caption style. The timeline may go, it isn't needed to style.
    case full

    /// Height for a usable height of `usable` points, inside the panel's limits.
    func height(for usable: CGFloat) -> CGFloat {
        switch self {
        case .mini: Self.clamp(0.27 * usable, 200, 250)
        case .medium: Self.clamp(0.38 * usable, 250, 340)
        case .full: Self.clamp(0.44 * usable, 300, 380)
        }
    }

    static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
