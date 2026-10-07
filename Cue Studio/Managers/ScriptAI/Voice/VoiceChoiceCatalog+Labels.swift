//
//  VoiceChoiceCatalog+Labels.swift
//  Cue Studio
//

import Foundation

nonisolated extension VoiceChoiceCatalog {
    /// What the creator reads for the opening style with this English id, in the language of the app (what is saved when they pick it).
    static func openingLabel(_ id: String) -> String {
        label(of: id, among: openings.map(\.id), in: VoicePersonalityItem.openings.options)
    }

    /// The same for an ending.
    static func endingLabel(_ id: String) -> String {
        label(of: id, among: endings.map(\.id), in: VoicePersonalityItem.endings.options)
    }

    private static func label(of id: String, among ids: [String], in options: [String]) -> String {
        guard let index = ids.firstIndex(of: id), options.indices.contains(index) else { return id }
        return options[index]
    }
}
