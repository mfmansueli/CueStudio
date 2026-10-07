//
//  VoiceBriefBuilder.swift
//  Cue Studio
//

import Foundation

/// Turns a creator's voice into the text the AI reads (plan stage 3). The order is what a small model follows best: who is talking,
/// who is watching and why, what about, how they sound, how they open and close, a few examples, and the rules that must hold at the very
/// end. What is known is used and what isn't is left out. Everything is in English and in the positive where it can be ("use plain
/// words") next to the "never": what the creator typed stays as typed.
///
/// The text fits `VoiceBrief.budget`: when it doesn't, the examples are shortened or dropped first, then the tags, then where and how long
/// they post. One piece of code builds it, measures it and shows it ("What Cue sends").
nonisolated enum VoiceBriefBuilder {
    static func brief(for voice: CreatorVoice, budget: Int = VoiceBrief.budget, register: PlatformRegister = .casual) -> VoiceBrief {
        let parts = Parts(voice, register: register)
        guard parts.hasContent else { return .empty }
        let full = parts.text(examples: parts.examples, tags: true, reach: true)
        let closing = closingRules(for: voice, register: register)
        if PromptCost.units(of: full) <= budget { return VoiceBrief(text: full, fullText: full, trimmed: [], closingRules: closing) }

        // Cutting goes in order: the examples (shortened to the room there is, or dropped), then the tags, then the reach.
        var dropped: [VoiceBrief.Trimmed] = []
        var best = (text: full, examples: parts.examples)
        for step: VoiceBrief.Trimmed? in [nil, .tags, .reach] {
            if let step {
                guard parts.has(step) else { continue }
                dropped.append(step)
            }
            let base = parts.text(examples: [], tags: !dropped.contains(.tags), reach: !dropped.contains(.reach))
            let fitted = fit(parts.examples, in: budget - PromptCost.units(of: base) - PromptCost.units(of: Parts.examplesHeader) - 1)
            best = (parts.text(examples: fitted, tags: !dropped.contains(.tags), reach: !dropped.contains(.reach)), fitted)
            if PromptCost.units(of: best.text) <= budget { break }
        }
        var trimmed: [VoiceBrief.Trimmed] = []
        if best.examples != parts.examples { trimmed.append(.examples) }
        trimmed += dropped
        return VoiceBrief(text: best.text, fullText: full, trimmed: trimmed, closingRules: closing)
    }

    /// The rules the request says again at its end.
    static func closingRules(for voice: CreatorVoice, register: PlatformRegister = .casual) -> [String] {
        var rules = [voice.resolvedSpeaksAs == .we ? "Say “we”, never “I”." : "Speak as one person (“I”)."]
        if register == .professional { rules.append("Keep it professional: no slang, no swearing, no emojis.") }
        if !voice.avoid.isEmpty {
            rules.append("Avoid: \(voice.avoid.map { VoiceAvoidRule.rule(for: $0)?.id.lowercased() ?? $0 }.joined(separator: ", ")).")
        }
        if !voice.openings.isEmpty {
            rules.append("Never write the name of an opening style" + (voice.phrases.isEmpty ? "." : " or open with a catchphrase."))
        }
        return rules
    }

    // MARK: - Examples

    /// The examples cut to what fits in `room` (`PromptCost`): all of them if they do, else fewer and shorter, none when less than a sentence would
    /// be left of each.
    private static func fit(_ examples: [String], in room: Int) -> [String] {
        guard !examples.isEmpty else { return [] }
        let wrapper = PromptCost.units(of: "- “” \n")
        for count in stride(from: examples.count, through: 1, by: -1) {
            let each = room / count - wrapper
            guard each >= Parts.shortestExample else { continue }
            return examples.prefix(count).map { PromptCost.shortened($0, toUnits: each) }
        }
        return []
    }

    // MARK: - The pieces

    /// The lines of the brief, by what they are about.
    private struct Parts {
        static let examplesHeader = "Here is how they write. Match the voice, never copy the content:"
        /// An example shorter than this says too little to be worth the room.
        static let shortestExample = 70

        let identity: [String]
        let audience: [String]
        let topics: [String]
        let voice: [String]
        let structure: [String]
        let reach: [String]
        let tags: [String]
        let rules: [String]
        let examples: [String]

        init(_ voice: CreatorVoice, register: PlatformRegister) {
            identity = Self.identity(voice)
            audience = Self.audience(voice)
            topics = Self.topics(voice)
            self.voice = Self.sound(voice, register: register)
            structure = Self.structure(voice)
            reach = Self.reach(voice)
            tags = Self.tags(voice)
            rules = Self.rules(voice)
            examples = Self.examples(voice)
        }

        /// Anything beyond the two lines every voice starts with.
        var hasContent: Bool {
            !(audience + topics + voice + structure + reach + tags + rules + examples).isEmpty || identity.count > 2
        }

        func has(_ step: VoiceBrief.Trimmed) -> Bool {
            switch step {
            case .examples: !examples.isEmpty
            case .tags: !tags.isEmpty
            case .reach: !reach.isEmpty
            }
        }

        func text(examples shown: [String], tags includeTags: Bool, reach includeReach: Bool) -> String {
            var lines = identity + audience + topics + voice + structure
            if includeReach { lines += reach }
            if includeTags { lines += tags }
            if !shown.isEmpty { lines += [Self.examplesHeader] + shown.map { "- “\($0)”" } }
            lines += rules
            return lines.joined(separator: "\n")
        }

        // MARK: Identity

        private static func identity(_ voice: CreatorVoice) -> [String] {
            var lines = ["Write in the creator's own voice. What follows says how they sound and who they speak to, never what the video is about."]
            if let custom = voice.customRole {
                lines.append("Who they are: \(custom).")
            } else if let role = voice.role {
                lines.append("Who they are: \(role.promptName).")
            }
            if let credential = voice.credential {
                lines.append("Credential: \(credential). Mention it only where it fits; never invent another.")
            }
            lines.append(
                voice.resolvedSpeaksAs == .we
                    ? "They speak as a team: say “we” and “our”, never “I”."
                    : "They speak as one person: say “I” and “my”."
            )
            return lines
        }

        // MARK: Audience

        private static func audience(_ voice: CreatorVoice) -> [String] {
            var lines: [String] = []
            if let who = voice.audienceNote ?? voice.audienceGroup?.promptName {
                lines.append("Their audience: \(who).")
            } else if voice.style.words == nil, let vocabulary = voice.vocabulary {
                lines.append(vocabularyRule(vocabulary))
            }
            if let level = voice.audienceLevel {
                lines.append(levelRule(level))
            }
            if !voice.watchReasons.isEmpty {
                lines.append("They watch to \(list(voice.watchReasons.map(\.promptPhrase))).")
            }
            if !voice.contentGoals.isEmpty {
                lines.append("Their videos aim to \(list(voice.contentGoals.map(\.promptPhrase))).")
            }
            return lines
        }

        private static func vocabularyRule(_ vocabulary: Vocabulary) -> String {
            switch vocabulary {
            case .simple: "Their audience is everyday people: use simple, everyday words."
            case .technical: "Their audience knows the field: technical terms are fine."
            case .genZ: "Their audience is young: use casual slang where it fits, without overdoing it."
            case .professional: "Their audience is professionals: use polished, professional wording."
            }
        }

        private static func levelRule(_ level: AudienceLevel) -> String {
            switch level {
            case .new: "They are new to the topic: explain terms and keep steps simple."
            case .some: "They know some basics: skip the obvious and go one level deeper."
            case .experienced: "They are experienced: use the field's terms and get to the point."
            }
        }

        // MARK: Topics

        private static func topics(_ voice: CreatorVoice) -> [String] {
            guard !voice.topics.isEmpty else { return [] }
            let names = voice.topics.map { entry in
                entry.subtopics.isEmpty ? entry.topic.promptName : "\(entry.topic.promptName) (\(entry.subtopics.joined(separator: ", ")))"
            }
            return ["Topics: \(names.joined(separator: "; "))."]
        }

        // MARK: How they sound

        private static func sound(_ voice: CreatorVoice, register: PlatformRegister) -> [String] {
            var lines: [String] = []
            if !voice.sounds.isEmpty {
                lines.append("They sound \(list(voice.sounds.map(\.promptWord))).")
            }
            var delivery: [String] = []
            if let energy = voice.style.energy { delivery.append("energy: \(energy.promptName)") }
            if let sentences = voice.style.sentences { delivery.append("sentences: \(sentences.promptName)") }
            // A professional platform has no slang, whatever the creator's words are elsewhere.
            if let words = voice.style.words { delivery.append("words: \((register == .professional && words == .someSlang ? .plain : words).promptName)") }
            if let humor = voice.reach.humor { delivery.append("humor: \(humor.promptName)") }
            if !delivery.isEmpty { lines.append("Delivery: \(delivery.joined(separator: "; ")).") }
            lines += VoiceFingerprintRules.lines(for: voice)
            if let swearing = voice.style.swearing ?? voice.swearing {
                lines.append(
                    swearing == .never || register == .professional
                        ? "Never swear."
                        : "Mild swearing is fine now and then. Never write strong swearing or slurs."
                )
            }
            // The legacy styles the creator can't have meant as a default: short sentences and conversational are what every new profile holds.
            let hints = voice.styles.filter { $0 != .shortSentences && $0 != .conversational }
            if !hints.isEmpty { lines.append("Style: \(hints.map(\.promptName).joined(separator: ", ")).") }
            return lines
        }

        // MARK: How they open, close and what they film

        private static func structure(_ voice: CreatorVoice) -> [String] {
            var lines: [String] = []
            if !voice.openings.isEmpty {
                let choices = voice.openings.map { VoiceChoiceCatalog.opening($0).guidance }
                lines.append("Open with \(list(choices, joiner: " or ")): show it in the script, never write the style's name.")
            }
            if !voice.endings.isEmpty {
                let choices = voice.endings.map(VoiceChoiceCatalog.endingAction)
                lines.append("End by \(list(choices, joiner: " or ")).")
            }
            let formats = voice.formats.map(\.promptName) + voice.customTags.filter(isFormatTag)
            if !formats.isEmpty {
                lines.append("They film mostly: \(formats.joined(separator: ", ")).")
            }
            if !voice.phrases.isEmpty {
                let said = voice.phrases.prefix(3).map { "“\($0)”" }.joined(separator: ", ")
                lines.append(
                    voice.openings.isEmpty
                        ? "They often say: \(said) — use one naturally, ideally in the opening."
                        : "They often say: \(said) — use one once after the first sentence, never as the first words."
                )
            }
            return lines
        }

        // MARK: Where, tags, rules, examples

        private static func reach(_ voice: CreatorVoice) -> [String] {
            var parts: [String] = []
            if !voice.reach.platforms.isEmpty { parts.append("they post on \(voice.reach.platforms.map(\.label).joined(separator: ", "))") }
            if let length = voice.reach.length { parts.append("videos are usually \(length.promptName)") }
            guard !parts.isEmpty else { return [] }
            let sentence = parts.joined(separator: "; ")
            return [sentence.prefix(1).uppercased() + sentence.dropFirst() + "."]
        }

        private static func tags(_ voice: CreatorVoice) -> [String] {
            let tags = voice.customTags.filter { !isFormatTag($0) }
            return tags.isEmpty ? [] : ["Also true of them: \(tags.joined(separator: ", "))."]
        }

        private static func rules(_ voice: CreatorVoice) -> [String] {
            guard !voice.avoid.isEmpty else { return [] }
            return ["Rules: \(voice.avoid.map(VoiceAvoidRule.instruction(for:)).joined(separator: "; "))."]
        }

        /// What was imported and fits the request first (`ExcerptRetriever`), then the examples the creator pasted, then the scripts approved with
        /// "Sounds like me", newest first; at most three.
        private static func examples(_ voice: CreatorVoice) -> [String] {
            let approved = voice.approvedSamples.reversed()
            let imported = voice.excerpts.map(\.asExample)
            return Array((imported + voice.examples + approved).map(\.sentText).prefix(VoiceExample.limit))
        }

        private static func isFormatTag(_ tag: String) -> Bool {
            VoiceQuestion.formatTags.values.contains { VoiceTextValidator.key($0) == VoiceTextValidator.key(tag) }
        }

        private static func list(_ items: [String], joiner: String = " and ") -> String {
            guard let last = items.last else { return "" }
            return items.count == 1 ? last : items.dropLast().joined(separator: ", ") + joiner + last
        }
    }
}
