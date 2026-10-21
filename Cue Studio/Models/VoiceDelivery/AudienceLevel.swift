//
//  AudienceLevel.swift
//  Cue Studio
//

import Foundation

/// How much the creator's audience already knows (08 E3, second part).
nonisolated enum AudienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case new, some, experienced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: String(localized: "New to it")
        case .some: String(localized: "Some basics")
        case .experienced: String(localized: "Experienced")
        }
    }

    /// What Cue does with it, under the choice.
    var explanation: String {
        switch self {
        case .new: String(localized: "Cue explains terms and keeps steps simple.")
        case .some: String(localized: "Cue skips the obvious and goes one level deeper.")
        case .experienced: String(localized: "Cue uses the field’s terms and gets to the point.")
        }
    }
}
