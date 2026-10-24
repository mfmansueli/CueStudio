//
//  CaptionShadowStyle.swift
//  Cue Studio
//

import Foundation

/// The light or dark around the caption's words (Caption style › Adjust › Shadow): a soft drop shadow, a dark halo wide and
/// dense enough to read the words against on any picture, or a glow in the words' own color.
nonisolated enum CaptionShadowStyle: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionShadowStyle.soft

    case none, soft, halo, glow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .soft: String(localized: "Soft")
        case .halo: String(localized: "Halo")
        case .glow: String(localized: "Glow")
        }
    }

    /// The shadow it draws for words in `textColor`; nil for none.
    func shadow(textColor: CaptionStyleSpec.RGB) -> CaptionStyleSpec.Shadow? {
        switch self {
        case .none: nil
        case .soft: CaptionStyleSpec.Shadow(opacity: 0.5, blur: 3, offsetY: 1)
        case .halo: CaptionStyleSpec.Shadow.halo
        case .glow: CaptionStyleSpec.Shadow(opacity: 0.85, blur: 9, offsetY: 0, color: textColor)
        }
    }

    /// The step a preset's shadow reads as.
    init(_ shadow: CaptionStyleSpec.Shadow?, textColor: CaptionStyleSpec.RGB) {
        guard let shadow else {
            self = .none
            return
        }
        if shadow.color == textColor, shadow.color != .black { self = .glow } else if shadow.passes > 1 { self = .halo } else { self = .soft }
    }
}
