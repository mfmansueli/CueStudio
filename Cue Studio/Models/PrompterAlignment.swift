//
//  PrompterAlignment.swift
//  Cue Studio
//

import Foundation

nonisolated enum PrompterAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading, center, trailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leading: String(localized: "Left")
        case .center: String(localized: "Center")
        case .trailing: String(localized: "Right")
        }
    }
}
