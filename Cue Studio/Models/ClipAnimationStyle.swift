//
//  ClipAnimationStyle.swift
//  Cue Studio
//

import Foundation

/// How a clip's picture comes in at its start or goes out at its end (Animation): from or to black, the same five both ways.
nonisolated enum ClipAnimationStyle: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = ClipAnimationStyle.fade

    /// Rises out of black, or sinks into it.
    case fade
    /// Comes up from below as it shows, or goes down as it fades.
    case rise
    /// Comes in from the side, or goes out the other side.
    case slide
    /// Grows into the frame, or shrinks away.
    case zoom
    /// Comes into focus, or goes out of it.
    case blur

    var id: String { rawValue }

    /// Its name on the clip's way in (`isIn`) or out.
    func label(isIn: Bool) -> String {
        isIn ? inLabel : outLabel
    }

    private var inLabel: String {
        switch self {
        case .fade: String(localized: "Fade in")
        case .rise: String(localized: "Slide up")
        case .slide: String(localized: "Slide in")
        case .zoom: String(localized: "Zoom in")
        case .blur: String(localized: "Blur")
        }
    }

    private var outLabel: String {
        switch self {
        case .fade: String(localized: "Fade out")
        case .rise: String(localized: "Slide down")
        case .slide: String(localized: "Slide out")
        case .zoom: String(localized: "Zoom out")
        case .blur: String(localized: "Blur")
        }
    }

    func systemImage(isIn: Bool) -> String {
        switch self {
        case .fade: "circle.lefthalf.filled"
        case .rise: isIn ? "arrow.up" : "arrow.down"
        case .slide: "arrow.right"
        case .zoom: isIn ? "plus.magnifyingglass" : "minus.magnifyingglass"
        case .blur: "aqi.medium"
        }
    }
}
