//
//  CaptionEntry.swift
//  Cue Studio
//

import Foundation

/// How a caption comes in and goes out (Caption style › Animation › In and out): at once, fading, popping to size with a
/// little overshoot, or rising a few points as it fades in. Short, so the words are read, not watched.
nonisolated enum CaptionEntry: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionEntry.fade

    case none, fade, pop, rise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .fade: String(localized: "Fade")
        case .pop: String(localized: "Pop")
        case .rise: String(localized: "Rise", comment: "Caption animation: the caption rises a little as it fades in")
        }
    }

    var systemImage: String {
        switch self {
        case .none: "rectangle"
        case .fade: "circle.lefthalf.filled"
        case .pop: "arrow.up.left.and.arrow.down.right"
        case .rise: "arrow.up"
        }
    }

    /// The numbers it draws with.
    var drawn: CaptionStyleSpec.Entry {
        switch self {
        case .none: .none
        case .fade: CaptionStyleSpec.Entry(fade: 0.15)
        case .pop: CaptionStyleSpec.Entry(fade: 0.06, popScale: 0.88, popDuration: 0.16)
        case .rise: CaptionStyleSpec.Entry(fade: 0.12, rise: 10, riseDuration: 0.18)
        }
    }
}
