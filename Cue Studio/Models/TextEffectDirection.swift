//
//  TextEffectDirection.swift
//  Cue Studio
//

import Foundation

/// Which way a text effect's motion (or depth) goes. Start and end follow the reading order: in Arabic, "from the start" is
/// from the right. Each kind offers its own few (`TextEffectKind.directions`).
nonisolated enum TextEffectDirection: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    static let fallback = TextEffectDirection.start

    /// From the first letter (or word) to the last.
    case start
    /// From the last to the first.
    case end
    /// From the middle out.
    case middle
    /// Rising into place.
    case up
    /// Dropping into place (Pop 3D: depth straight down).
    case down
    /// Depth toward the lower left.
    case left
    /// Depth toward the lower right.
    case right

    var id: String { rawValue }

    /// Its name in the panel's segments, for `kind`.
    func label(for kind: TextEffectKind) -> String {
        switch self {
        case .start: String(localized: "From start", comment: "Text effect direction: from the first letter to the last")
        case .end: String(localized: "From end", comment: "Text effect direction: from the last letter to the first")
        case .middle: String(localized: "From middle", comment: "Text effect direction: from the middle out")
        case .up: String(localized: "Rise", comment: "Text effect direction: words rise into place")
        case .down where kind == .pop3D: String(localized: "Down", comment: "Pop 3D text effect: depth straight down")
        case .down: String(localized: "Drop", comment: "Text effect direction: words drop into place")
        case .left: String(localized: "Left", comment: "Pop 3D text effect: depth toward the lower left")
        case .right: String(localized: "Right", comment: "Pop 3D text effect: depth toward the lower right")
        }
    }
}
