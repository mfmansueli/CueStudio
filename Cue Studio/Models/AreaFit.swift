//
//  AreaFit.swift
//  Cue Studio
//

import Foundation

/// How a picture takes its area of a split screen: covering it (what spills over is cropped) or whole inside it (bars of
/// black where it doesn't reach). Never stretched.
nonisolated enum AreaFit: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = AreaFit.fill

    case fill
    case fit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fill: String(localized: "Fill")
        case .fit: String(localized: "Fit")
        }
    }
}
