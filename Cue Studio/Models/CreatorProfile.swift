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
    /// How they come across: energy, sentences, words and swearing (v30 · 08 §1). Swearing used to be a field of its own.
    var style: VoiceDelivery
    /// What Cue should never write; `avoidNone` is the explicit "Nothing to avoid" (it counts as answered).
    var avoid: [String]
    var avoidNone: Bool
    /// Where they post, how long their videos are and how much humor they use.
    var reach: VoiceReach
    /// How much their audience already knows.
    var audienceLevel: AudienceLevel?
    /// How many times they said a script written in their voice "sounds like me"; every two count as one example.
    var approvals: Int
    /// Up to three of their own writings (`VoiceExample.limit`).
    var examples: [VoiceExample]
    /// Free tags added with "+ Something else" (2–40 characters each).
    var customTags: [String]
    /// Personality questions the creator answered "None of these" to: they are not asked again (and don't count as filled).
    var declinedVoiceItems: Set<VoicePersonalityItem>
    /// The photo (a small JPEG) the creator chose in Edit Profile; the avatar shows their initial without one. Stays on this iPhone.
    var photoData: Data?
    // My Cue Voice for Apple Intelligence (v2). Every field is optional in what was saved before: absent is empty / nil.
    /// Topics only My Cue Voice offers (`VoiceTopic`): with `niches` and `customTopics` at most `VoiceLimits.topics`. Not worlds in the universe.
    var voiceTopics: [VoiceTopic]
    /// Up to `VoiceLimits.details` subtopics under a topic, keyed by `VoiceTopicRef.id`: Cue's own are kept as their English text, typed ones as typed.
    var topicDetails: [String: [String]]
    /// Who is watching, as a group Cue offers (`audienceNote` is the creator's own words).
    var audienceGroup: AudienceGroup?
    /// The audience in the creator's own words ("Nurses on night shifts"); wins over `audienceGroup` when both are there.
    var audienceNote: String?
    /// Why the audience watches them (up to `WatchReason.limit`).
    var watchReasons: [WatchReason]
    /// What their videos are for (up to `ContentGoal.limit`).
    var contentGoals: [ContentGoal]
    /// A kind of creator in the creator's own words, in place of the eight (`role` is then left as the closest one, or nil).
    var customRole: String?
    /// A short credential ("Registered nurse"), for the AI to say it only when it is true of them.
    var credential: String?
    /// "I" or "we" in their scripts. Nil: the kind of creator decides (`CreatorRole.suggestedSpeaksAs`).
    var speaksAs: SpeaksAs?
    /// Scripts the creator approved with "Sounds like me" (up to `VoiceLimits.approvedSamples`, the oldest goes first): examples of their voice.
    var approvedSamples: [VoiceExample]
    /// A few sentences of what the creator imported ("Import my writing"), up to `VoiceExcerpt.limit`: the library each request picks examples from.
    var excerpts: [VoiceExcerpt]
    /// What was measured of that writing; nil when nothing was imported.
    var fingerprint: VoiceFingerprint?
    /// 1 before this work, `CreatorProfile.currentVoiceSchema` after.
    var voiceSchemaVersion: Int

    /// The version of the voice data this build writes.
    static let currentVoiceSchema = 2

    init(
        name: String = "", handle: String = "", niches: [Niche] = [], customTopics: [String] = [], phrases: [String] = [],
        role: CreatorRole? = nil, voiceApproved: Bool = false,
        sounds: [VoiceSound] = [.casual, .confident], vocabulary: Vocabulary = .simple,
        styles: [VoiceStyle] = [.shortSentences, .conversational], usesVoiceInAI: Bool = true,
        defaultPlatform: Platform = .tiktok, monetizationGoals: Bool = true,
        confirmedVoiceSteps: Set<VoiceSetupStep> = [], unverifiedVoiceSteps: Set<VoiceSetupStep> = [],
        openings: [String] = [], endings: [String] = [], formats: [ScriptType] = [], swearing: Swearing? = nil,
        style: VoiceDelivery = VoiceDelivery(), avoid: [String] = [], avoidNone: Bool = false, reach: VoiceReach = VoiceReach(),
        audienceLevel: AudienceLevel? = nil, approvals: Int = 0,
        examples: [VoiceExample] = [], customTags: [String] = [], declinedVoiceItems: Set<VoicePersonalityItem> = [],
        voiceTopics: [VoiceTopic] = [], topicDetails: [String: [String]] = [:], audienceGroup: AudienceGroup? = nil,
        audienceNote: String? = nil, watchReasons: [WatchReason] = [], contentGoals: [ContentGoal] = [], customRole: String? = nil,
        credential: String? = nil, speaksAs: SpeaksAs? = nil, approvedSamples: [VoiceExample] = [],
        excerpts: [VoiceExcerpt] = [], fingerprint: VoiceFingerprint? = nil,
        voiceSchemaVersion: Int = CreatorProfile.currentVoiceSchema
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
        self.style = style
        if let swearing { self.style.swearing = swearing }
        self.avoid = avoid
        self.avoidNone = avoidNone
        self.reach = reach
        self.audienceLevel = audienceLevel
        self.approvals = approvals
        self.examples = examples
        self.customTags = customTags
        self.declinedVoiceItems = declinedVoiceItems
        self.voiceTopics = voiceTopics
        self.topicDetails = topicDetails
        self.audienceGroup = audienceGroup
        self.audienceNote = audienceNote
        self.watchReasons = watchReasons
        self.contentGoals = contentGoals
        self.customRole = customRole
        self.credential = credential
        self.speaksAs = speaksAs
        self.approvedSamples = approvedSamples
        self.excerpts = Array(excerpts.prefix(VoiceExcerpt.limit))
        self.fingerprint = fingerprint
        self.voiceSchemaVersion = voiceSchemaVersion
    }

    var voice: CreatorVoice {
        // Only what the creator answered: the tones and the vocabulary a new profile starts with (or an older build saved unverified) are not theirs yet.
        CreatorVoice(
            sounds: hasAnswered(.tone) ? sounds : [], phrases: phrases, vocabulary: hasAnswered(.audience) ? vocabulary : nil,
            styles: styles, niches: niches, role: role,
            openings: openings, endings: endings, formats: formats, swearing: swearing, style: style, avoid: avoid, reach: reach,
            audienceLevel: audienceLevel, examples: examples, customTags: customTags,
            topics: topics.map { VoiceTopicEntry(topic: $0, subtopics: subtopics(of: $0)) },
            audienceGroup: audienceGroup, audienceNote: audienceNote, watchReasons: watchReasons, contentGoals: contentGoals,
            customRole: customRole, credential: credential, speaksAs: speaksAs, approvedSamples: approvedSamples,
            excerpts: ExcerptRetriever.pick(from: excerpts, limit: VoiceExample.limit), fingerprint: fingerprint
        )
    }

    /// The voice for something written in `language` (a code like "en" or "pt-BR"; nil is not known): the topics only when `idea` is about them (it says
    /// what the video is about; the voice says how they sound), of what the creator imported the excerpts in that language that fit it (a variety of how
    /// they open and go on, not a match of subject), and the measures only when they were taken in it.
    func voice(inLanguage language: String?, idea: String? = nil, professional: Bool = false, excerpts limit: Int = 2) -> CreatorVoice {
        var voice = self.voice
        // The idea says what the video is about: the topics are only sent when it is about them (`IdeaFocus`).
        voice.topics = IdeaFocus.topics(voice.topics, for: idea, language: language)
        voice.excerpts = ExcerptRetriever.pick(from: excerpts, context: .init(language: language, idea: idea, professional: professional), limit: limit)
        if let fingerprint, !fingerprint.applies(toLanguage: language) { voice.fingerprint = nil }
        return voice
    }

    /// Swearing moved into `style` (v30); the old name still reads and writes it.
    var swearing: Swearing? {
        get { style.swearing }
        set { style.swearing = newValue }
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
        case style, avoid, avoidNone, reach, audienceLevel, approvals
        case voiceTopics, topicDetails, audienceGroup, audienceNote, watchReasons, contentGoals, customRole, credential, speaksAs
        case approvedSamples, excerpts, fingerprint, voiceSchemaVersion
        case photoData = "photo"
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
        style = (try? container.decodeIfPresent(VoiceDelivery.self, forKey: .style)) ?? VoiceDelivery()
        // The old `swearing` field moves into the style: "never" or false is "never"; "mild" or true is "mild only".
        if style.swearing == nil {
            if let legacy = (try? container.decodeIfPresent(Swearing.self, forKey: .swearing)) ?? nil {
                style.swearing = legacy
            } else if let flag = (try? container.decodeIfPresent(Bool.self, forKey: .swearing)) ?? nil {
                style.swearing = flag ? .mild : .never
            }
        }
        avoid = try container.decodeIfPresent([String].self, forKey: .avoid) ?? defaults.avoid
        avoidNone = try container.decodeIfPresent(Bool.self, forKey: .avoidNone) ?? defaults.avoidNone
        reach = (try? container.decodeIfPresent(VoiceReach.self, forKey: .reach)) ?? VoiceReach()
        audienceLevel = (try? container.decodeIfPresent(AudienceLevel.self, forKey: .audienceLevel)) ?? nil
        approvals = try container.decodeIfPresent(Int.self, forKey: .approvals) ?? defaults.approvals
        examples = Array(((try? container.decodeIfPresent([VoiceExample].self, forKey: .examples)) ?? []).prefix(VoiceExample.limit))
        customTags = try container.decodeIfPresent([String].self, forKey: .customTags) ?? defaults.customTags
        declinedVoiceItems = (try? container.decodeIfPresent(Set<VoicePersonalityItem>.self, forKey: .declinedVoiceItems)) ?? []
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        // A value a newer build added (a topic, a group) reads as absent, so the rest of the profile still opens.
        voiceTopics = (try? container.decodeIfPresent([String].self, forKey: .voiceTopics))?.compactMap(VoiceTopic.init(rawValue:)) ?? []
        topicDetails = Self.cleaned(details: (try? container.decodeIfPresent([String: [String]].self, forKey: .topicDetails)) ?? [:])
        audienceGroup = (try? container.decodeIfPresent(AudienceGroup.self, forKey: .audienceGroup)) ?? nil
        audienceNote = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .audienceNote))
        watchReasons = Array(
            ((try? container.decodeIfPresent([String].self, forKey: .watchReasons)) ?? []).compactMap(WatchReason.init(rawValue:))
                .prefix(WatchReason.limit)
        )
        contentGoals = Array(
            ((try? container.decodeIfPresent([String].self, forKey: .contentGoals)) ?? []).compactMap(ContentGoal.init(rawValue:))
                .prefix(ContentGoal.limit)
        )
        customRole = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .customRole))
        credential = Self.trimmed(try? container.decodeIfPresent(String.self, forKey: .credential))
        speaksAs = (try? container.decodeIfPresent(SpeaksAs.self, forKey: .speaksAs)) ?? nil
        approvedSamples = Array(
            ((try? container.decodeIfPresent([VoiceExample].self, forKey: .approvedSamples)) ?? []).suffix(VoiceLimits.approvedSamples)
        )
        excerpts = Array(((try? container.decodeIfPresent([VoiceExcerpt].self, forKey: .excerpts)) ?? []).prefix(VoiceExcerpt.limit))
        fingerprint = (try? container.decodeIfPresent(VoiceFingerprint.self, forKey: .fingerprint)) ?? nil
        voiceSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .voiceSchemaVersion) ?? 1
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
        try container.encode(style, forKey: .style)
        try container.encode(avoid, forKey: .avoid)
        try container.encode(avoidNone, forKey: .avoidNone)
        try container.encode(reach, forKey: .reach)
        try container.encodeIfPresent(audienceLevel, forKey: .audienceLevel)
        try container.encode(approvals, forKey: .approvals)
        try container.encode(examples, forKey: .examples)
        try container.encode(customTags, forKey: .customTags)
        try container.encode(declinedVoiceItems, forKey: .declinedVoiceItems)
        try container.encodeIfPresent(photoData, forKey: .photoData)
        try container.encode(voiceTopics.map(\.rawValue), forKey: .voiceTopics)
        try container.encode(topicDetails, forKey: .topicDetails)
        try container.encodeIfPresent(audienceGroup, forKey: .audienceGroup)
        try container.encodeIfPresent(audienceNote, forKey: .audienceNote)
        try container.encode(watchReasons.map(\.rawValue), forKey: .watchReasons)
        try container.encode(contentGoals.map(\.rawValue), forKey: .contentGoals)
        try container.encodeIfPresent(customRole, forKey: .customRole)
        try container.encodeIfPresent(credential, forKey: .credential)
        try container.encodeIfPresent(speaksAs, forKey: .speaksAs)
        try container.encode(approvedSamples, forKey: .approvedSamples)
        try container.encode(excerpts, forKey: .excerpts)
        try container.encodeIfPresent(fingerprint, forKey: .fingerprint)
        // Anything this build writes is of the current version, whatever it was read as.
        try container.encode(Self.currentVoiceSchema, forKey: .voiceSchemaVersion)
    }

    /// Text typed by the creator: trimmed, and nil when nothing is left.
    private static func trimmed(_ text: String?) -> String? {
        guard let text else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Subtopics as they are kept: trimmed, without repeats, at most `VoiceLimits.details` under a topic, and no topic without any.
    private static func cleaned(details: [String: [String]]) -> [String: [String]] {
        details.compactMapValues { values in
            var seen = Set<String>()
            let kept = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
                .prefix(VoiceLimits.details)
            return kept.isEmpty ? nil : Array(kept)
        }
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
