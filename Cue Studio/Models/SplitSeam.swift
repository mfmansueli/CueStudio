//
//  SplitSeam.swift
//  Cue Studio
//

import Foundation

/// How the seam between the two areas of a split screen looks: a plain cut, a thin line, the two pictures melting into each
/// other in a soft band (Blur), or a dark band across it (Shadow, which also lifts captions sitting on it).
nonisolated enum SplitSeam: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = SplitSeam.none

    case none
    case line
    case blur
    case shadow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(inInterfaceLanguage: LocalizedStringResource("splitSeam.none", defaultValue: "None"))
        case .line: String(inInterfaceLanguage: LocalizedStringResource("splitSeam.line", defaultValue: "Line"))
        case .blur: String(inInterfaceLanguage: LocalizedStringResource("splitSeam.blur", defaultValue: "Blur"))
        case .shadow: String(inInterfaceLanguage: LocalizedStringResource("splitSeam.shadow", defaultValue: "Shadow"))
        }
    }

    /// The share of the frame's short side the effect spreads over, each side of the seam (0 for a plain cut).
    var band: Double {
        switch self {
        case .none: 0
        case .line: 0.002
        case .blur: 0.06
        case .shadow: 0.1
        }
    }
}
