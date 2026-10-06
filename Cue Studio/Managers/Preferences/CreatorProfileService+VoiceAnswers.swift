//
//  CreatorProfileService+VoiceAnswers.swift
//  Cue Studio
//

import Foundation

/// Answers to the question bank (08 §2): the tip's sheet and the full page write through here, so the dock's "✦ Voice nn%" and the
/// meter follow every tap. One tap on a single-answer question saves it; a multiple-answer question toggles.
extension CreatorProfileService {
    // MARK: - Reading

    /// Whether `option` is what the profile holds for `question` (a selected row).
    func isSelected(_ option: VoiceOption, for question: VoiceQuestion) -> Bool {
        let held = profile
        switch question {
        case .role: return held.role?.rawValue == option.id
        case .topics: return held.niches.contains { $0.rawValue == option.id }
        case .audience: return held.isChosen(.audience) && held.vocabulary.rawValue == option.id
        case .tone: return held.isChosen(.tone) && held.sounds.contains { $0.rawValue == option.id }
        case .endings: return Self.holds(option.id, in: held.endings)
        case .openings: return Self.holds(option.id, in: held.openings)
        case .phrases: return Self.holds(option.id, in: held.phrases)
        case .formats: return isFormatSelected(option, in: held)
        case .length, .humor, .platforms: return isReachSelected(option, for: question, in: held)
        case .energy, .sentences, .words, .swearing: return isStyleSelected(option, for: question, in: held)
        case .avoid: return option.id == VoiceQuestion.nothingToAvoidID ? held.avoidNone : Self.holds(option.id, in: held.avoid)
        case .example: return false
        }
    }

    private static func holds(_ value: String, in list: [String]) -> Bool {
        list.contains { VoiceTextValidator.key($0) == VoiceTextValidator.key(value) }
    }

    private func isFormatSelected(_ option: VoiceOption, in held: CreatorProfile) -> Bool {
        if option.id == VoiceQuestion.talkingHeadID { return Self.holds(CreatorProfile.talkingHeadTag, in: held.customTags) }
        return held.formats.contains { $0.rawValue == option.id }
    }

    private func isReachSelected(_ option: VoiceOption, for question: VoiceQuestion, in held: CreatorProfile) -> Bool {
        switch question {
        case .length: held.reach.length?.rawValue == option.id
        case .humor: held.reach.humor?.rawValue == option.id
        default: held.reach.platforms.contains { $0.rawValue == option.id }
        }
    }

    private func isStyleSelected(_ option: VoiceOption, for question: VoiceQuestion, in held: CreatorProfile) -> Bool {
        switch question {
        case .energy: held.style.energy?.rawValue == option.id
        case .sentences: held.style.sentences?.rawValue == option.id
        case .words: held.style.words?.rawValue == option.id
        default: held.style.swearing?.rawValue == option.id
        }
    }

    // MARK: - Answering

    /// Taps an answer. Single-answer questions replace what was there; multiple-answer ones toggle (and say when one more would
    /// go over the limit).
    @discardableResult
    func answer(_ question: VoiceQuestion, with option: VoiceOption) -> VoiceEditResult {
        switch question {
        case .role, .topics, .audience, .tone: return answerEssential(question, with: option)
        case .endings, .openings, .phrases:
            guard let item = Self.personalityItem(for: question) else { return .alreadyThere }
            return toggle(option.id, for: item)
        case .formats: return toggleFormat(option)
        case .length, .humor, .platforms, .energy, .sentences, .words, .swearing: return answerDelivery(question, with: option)
        case .avoid: return answerAvoid(option)
        case .example: return .alreadyThere
        }
    }

    private func answerEssential(_ question: VoiceQuestion, with option: VoiceOption) -> VoiceEditResult {
        var updated = profile
        let result: VoiceEditResult
        switch question {
        case .role:
            updated.role = CreatorRole(rawValue: option.id)
            result = .added
        case .topics:
            guard let niche = Niche(rawValue: option.id) else { return .alreadyThere }
            if let index = updated.niches.firstIndex(of: niche) {
                updated.niches.remove(at: index)
                result = .removed
            } else if updated.niches.count + updated.customTopics.count >= VoiceLimits.topics {
                return .limit(VoiceLimits.message(max: VoiceLimits.topics, noun: String(localized: "topics")))
            } else {
                updated.niches.append(niche)
                result = .added
            }
        case .audience:
            guard let vocabulary = Vocabulary(rawValue: option.id) else { return .alreadyThere }
            updated.vocabulary = vocabulary
            updated.confirm(.audience)
            result = .added
        default:
            guard let toggled = Self.toggleSound(option, in: &updated) else { return .alreadyThere }
            if case .limit = toggled { return toggled }
            result = toggled
        }
        profile = updated
        return result
    }

    /// Picks or drops a tone. The first answer starts from nothing: the default tones of a new profile never ride along.
    private static func toggleSound(_ option: VoiceOption, in updated: inout CreatorProfile) -> VoiceEditResult? {
        guard let sound = VoiceSound(rawValue: option.id) else { return nil }
        if !updated.isChosen(.tone) { updated.sounds = [] }
        let result: VoiceEditResult
        if let index = updated.sounds.firstIndex(of: sound) {
            guard updated.sounds.count > 1 else { return nil }
            updated.sounds.remove(at: index)
            result = .removed
        } else if updated.sounds.count >= VoiceLimits.tones {
            return .limit(VoiceLimits.message(max: VoiceLimits.tones, noun: String(localized: "tones")))
        } else {
            updated.sounds.append(sound)
            result = .added
        }
        updated.confirm(.tone)
        return result
    }

    private func answerDelivery(_ question: VoiceQuestion, with option: VoiceOption) -> VoiceEditResult {
        var updated = profile
        switch question {
        case .length: updated.reach.length = VideoLength(rawValue: option.id)
        case .humor: updated.reach.humor = HumorLevel(rawValue: option.id)
        case .platforms: updated.reach.platforms = Platform(rawValue: option.id).map { [$0] } ?? []
        case .energy: updated.style.energy = VoiceEnergy(rawValue: option.id)
        case .sentences: updated.style.sentences = SentenceLength(rawValue: option.id)
        case .words: updated.style.words = WordLevel(rawValue: option.id)
        default: updated.style.swearing = Swearing(rawValue: option.id)
        }
        profile = updated
        return .added
    }

    private func answerAvoid(_ option: VoiceOption) -> VoiceEditResult {
        var updated = profile
        let result: VoiceEditResult
        if option.id == VoiceQuestion.nothingToAvoidID {
            updated.avoidNone.toggle()
            if updated.avoidNone { updated.avoid = [] }
            result = updated.avoidNone ? .added : .removed
        } else if let index = updated.avoid.firstIndex(where: { VoiceTextValidator.key($0) == VoiceTextValidator.key(option.id) }) {
            updated.avoid.remove(at: index)
            result = .removed
        } else if updated.avoid.count >= VoiceLimits.avoid {
            return .limit(VoiceLimits.message(max: VoiceLimits.avoid, noun: String(localized: "items")))
        } else {
            updated.avoid.append(option.id)
            updated.avoidNone = false
            result = .added
        }
        profile = updated
        return result
    }

    /// The second part of "Who's watching?": how much the audience already knows.
    func answerAudienceLevel(_ level: AudienceLevel) {
        profile.audienceLevel = level
    }

    /// "+ Something else": text the creator typed, checked first (04 §F9). Where the app has no list for it (kind of creator, tone,
    /// audience, formats), it is kept as something true of them.
    @discardableResult
    func addSomethingElse(_ raw: String, for question: VoiceQuestion, keepingTyped: Bool = false) -> VoiceEditResult {
        switch question {
        case .endings, .openings, .phrases:
            guard let item = Self.personalityItem(for: question) else { return .alreadyThere }
            return addCustom(raw, for: item, keepingTyped: keepingTyped)
        case .avoid:
            return addText(
                raw, vocabulary: keepingTyped ? [] : question.options.map(\.label), existing: profile.avoid,
                limit: (VoiceLimits.avoid, String(localized: "items"))
            ) {
                $0.avoid.append($1)
                $0.avoidNone = false
            }
        case .topics:
            let existing = profile.customTopics + profile.niches.map(\.label)
            let held = profile.niches.count + profile.customTopics.count
            return addText(
                raw, vocabulary: keepingTyped ? [] : Niche.allCases.map(\.chipLabel), existing: existing,
                held: held, limit: (VoiceLimits.topics, String(localized: "topics"))
            ) { $0.customTopics.append($1) }
        default:
            return addText(raw, vocabulary: [], existing: profile.customTags, limit: (Int.max, "")) { $0.customTags.append($1) }
        }
    }

    /// Checks `raw` and, when it is good, lets `insert` add it to a copy of the profile.
    private func addText(
        _ raw: String, vocabulary: [String], existing: [String], held: Int? = nil, limit: (max: Int, noun: String),
        insert: (inout CreatorProfile, String) -> Void
    ) -> VoiceEditResult {
        switch VoiceTextValidator.check(raw, existing: existing, vocabulary: vocabulary) {
        case .tooShort, .tooLong, .blocked: return .rejected(VoiceTextValidator.check(raw, existing: existing))
        case .duplicate: return .alreadyThere
        case .typo(let suggestion, let original): return .suggest(suggestion: suggestion, original: original)
        case .accepted(let text):
            guard (held ?? existing.count) < limit.max else { return .limit(VoiceLimits.message(max: limit.max, noun: limit.noun)) }
            var updated = profile
            insert(&updated, text)
            profile = updated
            return .added
        }
    }

    // MARK: - Helpers

    private func toggleFormat(_ option: VoiceOption) -> VoiceEditResult {
        if option.id == VoiceQuestion.talkingHeadID {
            var updated = profile
            let key = VoiceTextValidator.key(CreatorProfile.talkingHeadTag)
            if let index = updated.customTags.firstIndex(where: { VoiceTextValidator.key($0) == key }) {
                updated.customTags.remove(at: index)
                profile = updated
                return .removed
            }
            guard updated.formats.count < VoiceLimits.formats else {
                return .limit(VoiceLimits.message(max: VoiceLimits.formats, noun: String(localized: "formats")))
            }
            updated.customTags.append(CreatorProfile.talkingHeadTag)
            profile = updated
            return .added
        }
        guard let format = ScriptType(rawValue: option.id) else { return .alreadyThere }
        return toggle(format: format)
    }

    private static func personalityItem(for question: VoiceQuestion) -> VoicePersonalityItem? {
        switch question {
        case .endings: .endings
        case .openings: .openings
        case .phrases: .phrases
        default: nil
        }
    }
}
