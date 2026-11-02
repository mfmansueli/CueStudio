//
//  AddressForm.swift
//  Cue Studio
//

import Foundation

/// How the script speaks to the viewer in the languages that have two ways ("tú" or "usted", "tu" or "vous", "du" or "Sie"): the owner's B8
/// (02/11/2026; §11.7). Informal unless the creator picks formal; Cue may suggest formal, never decide it.
nonisolated enum AddressForm: String, Codable, CaseIterable, Identifiable, Sendable {
    case informal, formal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .informal: String(localized: "Informal")
        case .formal: String(localized: "Formal")
        }
    }
}
