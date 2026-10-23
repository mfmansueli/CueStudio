//
//  CoverTemplate.swift
//  Cue Studio
//

import Foundation

/// Where a cover starts: a few finished looks for the videos creators make most, each one a full composition (type, place,
/// highlight, elements, effect) the creator then changes (`CoverComposition.make`). Each works with short and long titles and
/// with light and dark pictures: the words fit their block (`CoverTextLayout`) and sit on a shade, an outline or a box.
nonisolated enum CoverTemplate: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CoverTemplate.educational

    /// Teaching something: the title low, in clean type, the key word on a yellow box.
    case educational
    /// A strong take: big condensed words up top, outlined, the picture dimmed.
    case opinion
    /// A listicle: the number big, the rest under it.
    case list
    /// Showing something: the title in a box at the top, a circle and an arrow on what matters.
    case demo
    /// A result: two pictures side by side, BEFORE and AFTER.
    case beforeAfter
    /// One of a series: the episode tag over the title, the same look every time.
    case series

    var id: String { rawValue }

    var label: String {
        switch self {
        case .educational: String(localized: "Educational")
        case .opinion: String(localized: "Opinion")
        case .list: String(localized: "List")
        case .demo: String(localized: "Demo")
        case .beforeAfter: String(localized: "Before/After")
        case .series: String(localized: "Series")
        }
    }
}
