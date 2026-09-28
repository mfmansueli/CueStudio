//
//  CreatorProfile.swift
//  Cue Studio
//

import Foundation

/// The creator's profile and Creator Voice: what the AI uses to write scripts that sound like them,
/// plus the defaults new scripts start with. One voice for every platform. Stays on the device.
nonisolated struct CreatorProfile: Codable, Hashable, Sendable {
    var name: String
    var handle: String
    var niches: [Niche]
    /// Catchphrases the creator always says ("Hey fam").
    var phrases: [String]
    /// "How I sound".
    var sounds: [VoiceSound]
    var vocabulary: Vocabulary
    var styles: [VoiceStyle]
    /// "Use my voice in AI scripts": the default of "Write in my voice" when generating.
    var usesVoiceInAI: Bool
    var defaultPlatform: Platform
    /// Aims length goals at what earns money (TikTok 1:00+, YouTube 8:00+).
    var monetizationGoals: Bool

    init(
        name: String = "", handle: String = "", niches: [Niche] = [], phrases: [String] = [],
        sounds: [VoiceSound] = [.casual, .confident], vocabulary: Vocabulary = .simple,
        styles: [VoiceStyle] = [.shortSentences, .conversational], usesVoiceInAI: Bool = true,
        defaultPlatform: Platform = .tiktok, monetizationGoals: Bool = true
    ) {
        self.name = name
        self.handle = handle
        self.niches = niches
        self.phrases = phrases
        self.sounds = sounds
        self.vocabulary = vocabulary
        self.styles = styles
        self.usesVoiceInAI = usesVoiceInAI
        self.defaultPlatform = defaultPlatform
        self.monetizationGoals = monetizationGoals
    }

    var voice: CreatorVoice {
        CreatorVoice(sounds: sounds, phrases: phrases, vocabulary: vocabulary, styles: styles, niches: niches)
    }

    /// The voice the AI writes with on this plan: sounds, phrases and niche are free; vocabulary and
    /// style are part of Pro.
    func voice(unlocking tier: MembershipTier) -> CreatorVoice {
        var voice = voice
        guard !ProFeature.fullCreatorVoice.isUnlocked(for: tier) else { return voice }
        voice.vocabulary = nil
        voice.styles = []
        return voice
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "Your name") : trimmed
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case name, handle, niches, phrases, sounds, vocabulary, styles, usesVoiceInAI, defaultPlatform, monetizationGoals
        /// v1 kept a single tone; it becomes the first "How I sound".
        case legacyTone = "tone"
    }

    /// Every field is optional so profiles saved by older builds keep their values and pick up the
    /// defaults for anything new.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = CreatorProfile()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? defaults.name
        handle = try container.decodeIfPresent(String.self, forKey: .handle) ?? defaults.handle
        niches = try container.decodeIfPresent([Niche].self, forKey: .niches) ?? defaults.niches
        phrases = try container.decodeIfPresent([String].self, forKey: .phrases) ?? defaults.phrases
        if let sounds = try container.decodeIfPresent([VoiceSound].self, forKey: .sounds) {
            self.sounds = sounds
        } else if let tone = try container.decodeIfPresent(Tone.self, forKey: .legacyTone) {
            sounds = Self.sounds(migratingFrom: tone)
        } else {
            sounds = defaults.sounds
        }
        vocabulary = try container.decodeIfPresent(Vocabulary.self, forKey: .vocabulary) ?? defaults.vocabulary
        styles = try container.decodeIfPresent([VoiceStyle].self, forKey: .styles) ?? defaults.styles
        usesVoiceInAI = try container.decodeIfPresent(Bool.self, forKey: .usesVoiceInAI) ?? defaults.usesVoiceInAI
        defaultPlatform = try container.decodeIfPresent(Platform.self, forKey: .defaultPlatform) ?? defaults.defaultPlatform
        monetizationGoals = try container.decodeIfPresent(Bool.self, forKey: .monetizationGoals) ?? defaults.monetizationGoals
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(handle, forKey: .handle)
        try container.encode(niches, forKey: .niches)
        try container.encode(phrases, forKey: .phrases)
        try container.encode(sounds, forKey: .sounds)
        try container.encode(vocabulary, forKey: .vocabulary)
        try container.encode(styles, forKey: .styles)
        try container.encode(usesVoiceInAI, forKey: .usesVoiceInAI)
        try container.encode(defaultPlatform, forKey: .defaultPlatform)
        try container.encode(monetizationGoals, forKey: .monetizationGoals)
    }

    static func sounds(migratingFrom tone: Tone) -> [VoiceSound] {
        switch tone {
        case .energetic: [.energetic]
        case .expert: [.professional]
        case .funny: [.funny]
        default: [.casual]
        }
    }
}
