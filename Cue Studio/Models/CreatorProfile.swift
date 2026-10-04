//
//  CreatorProfile.swift
//  Cue Studio
//

import Foundation

/// The creator's profile and My Cue Voice: what the AI uses to write scripts that sound like them,
/// plus the defaults new scripts start with. One voice for every platform. Stays on the device.
nonisolated struct CreatorProfile: Codable, Hashable, Sendable {
    var name: String
    var handle: String
    var niches: [Niche]
    /// Topics the creator typed in the first flight ("+ Your own"); with `niches` they make the universe (at most three).
    var customTopics: [String]
    /// Catchphrases the creator always says ("Hey fam").
    var phrases: [String]
    /// "What kind of creator are you?": the first question of My Cue Voice. Optional.
    var role: CreatorRole?
    /// The creator said a script written in their voice "sounds like me" (the preview strip on the
    /// script page stops asking).
    var voiceApproved: Bool
    /// "How I sound".
    var sounds: [VoiceSound]
    var vocabulary: Vocabulary
    var styles: [VoiceStyle]
    /// "Use my voice in AI scripts": the default of "Write in my voice" when generating.
    var usesVoiceInAI: Bool
    var defaultPlatform: Platform
    /// Aims length goals at what earns money (TikTok 1:00+, YouTube 8:00+).
    var monetizationGoals: Bool
    /// The voice steps (`.audience`, `.tone`) the creator answered, as opposed to the defaults above.
    /// Niches are not stored here: they start empty, so having one is the answer.
    var confirmedVoiceSteps: Set<VoiceSetupStep>
    /// Steps (`.audience`, `.tone`) whose values were saved by a build that didn't track the creator's
    /// answers: they may be choices or the defaults, so they are kept, shown as the current values,
    /// and confirmed with one tap before the voice is first used.
    var unverifiedVoiceSteps: Set<VoiceSetupStep>
    // My Cue Voice, layers 2 and 3 (v29). Absent in a profile saved before: empty / nil.
    /// How they like to open a video ("Okay, real talk.").
    var openings: [String]
    /// How they usually end one ("Save this for later.").
    var endings: [String]
    /// What they film most.
    var formats: [ScriptType]
    var swearing: Swearing?
    /// Up to three of their own writings (`VoiceExample.limit`).
    var examples: [VoiceExample]
    /// Free tags added with "+ Something else" (2–40 characters each).
    var customTags: [String]
    /// Personality questions the creator answered "None of these" to: they are not asked again (and don't count as filled).
    var declinedVoiceItems: Set<VoicePersonalityItem>

    init(
        name: String = "", handle: String = "", niches: [Niche] = [], customTopics: [String] = [], phrases: [String] = [],
        role: CreatorRole? = nil, voiceApproved: Bool = false,
        sounds: [VoiceSound] = [.casual, .confident], vocabulary: Vocabulary = .simple,
        styles: [VoiceStyle] = [.shortSentences, .conversational], usesVoiceInAI: Bool = true,
        defaultPlatform: Platform = .tiktok, monetizationGoals: Bool = true,
        confirmedVoiceSteps: Set<VoiceSetupStep> = [], unverifiedVoiceSteps: Set<VoiceSetupStep> = [],
        openings: [String] = [], endings: [String] = [], formats: [ScriptType] = [], swearing: Swearing? = nil,
        examples: [VoiceExample] = [], customTags: [String] = [], declinedVoiceItems: Set<VoicePersonalityItem> = []
    ) {
        self.name = name
        self.handle = handle
        self.niches = niches
        self.customTopics = customTopics
        self.phrases = phrases
        self.role = role
        self.voiceApproved = voiceApproved
        self.sounds = sounds
        self.vocabulary = vocabulary
        self.styles = styles
        self.usesVoiceInAI = usesVoiceInAI
        self.defaultPlatform = defaultPlatform
        self.monetizationGoals = monetizationGoals
        self.confirmedVoiceSteps = confirmedVoiceSteps
        self.unverifiedVoiceSteps = unverifiedVoiceSteps
        self.openings = openings
        self.endings = endings
        self.formats = formats
        self.swearing = swearing
        self.examples = examples
        self.customTags = customTags
        self.declinedVoiceItems = declinedVoiceItems
    }

    var voice: CreatorVoice {
        CreatorVoice(
            sounds: sounds, phrases: phrases, vocabulary: vocabulary, styles: styles, niches: niches, role: role,
            openings: openings, endings: endings, formats: formats, swearing: swearing, examples: examples,
            customTags: customTags
        )
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
        case name, handle, niches, customTopics, phrases, role, voiceApproved, sounds, vocabulary, styles, usesVoiceInAI, defaultPlatform, monetizationGoals
        case confirmedVoiceSteps, unverifiedVoiceSteps
        case openings, endings, formats, swearing, examples, customTags, declinedVoiceItems
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
        customTopics = try container.decodeIfPresent([String].self, forKey: .customTopics) ?? defaults.customTopics
        phrases = try container.decodeIfPresent([String].self, forKey: .phrases) ?? defaults.phrases
        role = try container.decodeIfPresent(CreatorRole.self, forKey: .role)
        voiceApproved = try container.decodeIfPresent(Bool.self, forKey: .voiceApproved) ?? defaults.voiceApproved
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
        confirmedVoiceSteps = try container.decodeIfPresent(Set<VoiceSetupStep>.self, forKey: .confirmedVoiceSteps) ?? defaults.confirmedVoiceSteps
        openings = try container.decodeIfPresent([String].self, forKey: .openings) ?? defaults.openings
        endings = try container.decodeIfPresent([String].self, forKey: .endings) ?? defaults.endings
        // A format a newer build added reads as absent, so the rest of the profile still opens.
        formats = (try? container.decodeIfPresent([String].self, forKey: .formats))?.compactMap(ScriptType.init(rawValue:)) ?? defaults.formats
        swearing = (try? container.decodeIfPresent(Swearing.self, forKey: .swearing)) ?? nil
        examples = Array(((try? container.decodeIfPresent([VoiceExample].self, forKey: .examples)) ?? []).prefix(VoiceExample.limit))
        customTags = try container.decodeIfPresent([String].self, forKey: .customTags) ?? defaults.customTags
        declinedVoiceItems = (try? container.decodeIfPresent(Set<VoicePersonalityItem>.self, forKey: .declinedVoiceItems)) ?? []
        if let unverified = try container.decodeIfPresent(Set<VoiceSetupStep>.self, forKey: .unverifiedVoiceSteps) {
            unverifiedVoiceSteps = unverified
        } else if container.contains(.confirmedVoiceSteps) {
            unverifiedVoiceSteps = []
        } else {
            // Saved before answers were tracked: whatever it holds may be the creator's own choice.
            var legacy: Set<VoiceSetupStep> = []
            if container.contains(.vocabulary) { legacy.insert(.audience) }
            if container.contains(.sounds) || container.contains(.legacyTone) { legacy.insert(.tone) }
            unverifiedVoiceSteps = legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(handle, forKey: .handle)
        try container.encode(niches, forKey: .niches)
        try container.encode(customTopics, forKey: .customTopics)
        try container.encode(phrases, forKey: .phrases)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encode(voiceApproved, forKey: .voiceApproved)
        try container.encode(sounds, forKey: .sounds)
        try container.encode(vocabulary, forKey: .vocabulary)
        try container.encode(styles, forKey: .styles)
        try container.encode(usesVoiceInAI, forKey: .usesVoiceInAI)
        try container.encode(defaultPlatform, forKey: .defaultPlatform)
        try container.encode(monetizationGoals, forKey: .monetizationGoals)
        try container.encode(confirmedVoiceSteps, forKey: .confirmedVoiceSteps)
        try container.encode(unverifiedVoiceSteps, forKey: .unverifiedVoiceSteps)
        try container.encode(openings, forKey: .openings)
        try container.encode(endings, forKey: .endings)
        try container.encode(formats.map(\.rawValue), forKey: .formats)
        try container.encodeIfPresent(swearing, forKey: .swearing)
        try container.encode(examples, forKey: .examples)
        try container.encode(customTags, forKey: .customTags)
        try container.encode(declinedVoiceItems, forKey: .declinedVoiceItems)
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
