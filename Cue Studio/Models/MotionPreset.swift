//
//  MotionPreset.swift
//  Cue Studio
//

import Foundation

/// A ready-made way for a text or a photo or video to come in (and go out): what Motion offers before keyframes.
nonisolated enum MotionPreset: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = MotionPreset.fade

    /// Fades in.
    case fade
    /// Rises a little as it fades in.
    case slideUp
    /// Comes in from the side.
    case slideIn
    /// Grows slowly the whole time it shows.
    case gentleZoom
    /// Pops in, a little past its size, then settles: to make it stand out.
    case pop
    /// Fades and rises in, then fades out before it ends.
    case inAndOut

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fade: String(localized: "Fade in")
        case .slideUp: String(localized: "Slide up")
        case .slideIn: String(localized: "Slide in")
        case .gentleZoom: String(localized: "Gentle zoom")
        case .pop: String(localized: "Pop")
        case .inAndOut: String(localized: "In and out")
        }
    }

    var systemImage: String {
        switch self {
        case .fade: "circle.lefthalf.filled"
        case .slideUp: "arrow.up"
        case .slideIn: "arrow.right"
        case .gentleZoom: "plus.magnifyingglass"
        case .pop: "sparkle"
        case .inAndOut: "arrow.up.and.down"
        }
    }

    /// Whether it lasts the item's whole time (the zoom), rather than its first moments.
    var spansTheWholeItem: Bool { self == .gentleZoom }
}
