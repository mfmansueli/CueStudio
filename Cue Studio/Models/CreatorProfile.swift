//
//  CreatorProfile.swift
//  Cue Studio
//

import Foundation

/// The creator's "DNA": what the AI uses to write scripts that sound like them, plus the defaults
/// new scripts start with. Stays on the device.
nonisolated struct CreatorProfile: Codable, Hashable, Sendable {
    var name: String = ""
    var handle: String = ""
    var niches: [Niche] = []
    /// Catchphrases the creator always says ("Hey fam").
    var phrases: [String] = []
    var tone: Tone = .casual
    var defaultPlatform: Platform = .tiktok
    /// Aims length goals at what earns money (TikTok 1:00+, YouTube 8:00+).
    var monetizationGoals: Bool = true

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "Your name") : trimmed
    }
}
