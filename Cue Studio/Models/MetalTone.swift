//
//  MetalTone.swift
//  Cue Studio
//

import Foundation

/// The metal the Gold effect is made of. Each is a set of tonal bands from a bright top to a darker horizon and back, so the
/// letters read as polished metal rather than a flat yellow.
nonisolated enum MetalTone: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    static let fallback = MetalTone.gold

    case gold, rose, silver

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gold: String(localized: "Gold", comment: "Metal tone of the Gold text effect")
        case .rose: String(localized: "Rose gold", comment: "Metal tone of the Gold text effect")
        case .silver: String(localized: "Silver", comment: "Metal tone of the Gold text effect")
        }
    }
}
