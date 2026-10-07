//
//  CreatorProfileService+VoiceDetails.swift
//  Cue Studio
//

import Foundation

/// What My Cue Voice for Apple Intelligence added to the answers (plan stage 2): topics of any kind with their subtopics, who is
/// watching and why, what the videos are for, and who is talking. Every write goes through here, so the editor, the guided flow and the
/// dock all follow the same limits and checks.
extension CreatorProfileService {
    // MARK: - Topics

    /// The topic an option id stands for: one of the ten, or one only the voice offers.
    nonisolated static func topicRef(for id: String) -> VoiceTopicRef? {
        if let niche = Niche(rawValue: id) { return .niche(niche) }
        if let topic = VoiceTopic(rawValue: id) { return .extra(topic) }
        return nil
    }

    /// Puts a topic in or takes it out of `profile` (and its subtopics with it). One more than `VoiceLimits.topics` is refused, whatever the kinds.
    static func toggle(_ topic: VoiceTopicRef, in profile: inout CreatorProfile) -> VoiceEditResult {
        let isHeld: Bool
        switch topic {
        case .niche(let niche): isHeld = profile.niches.contains(niche)
        case .extra(let extra): isHeld = profile.voiceTopics.contains(extra)
        case .custom(let name): isHeld = profile.customTopics.contains { VoiceTextValidator.key($0) == VoiceTextValidator.key(name) }
        }
        if isHeld {
            switch topic {
            case .niche(let niche): profile.niches.removeAll { $0 == niche }
            case .extra(let extra): profile.voiceTopics.removeAll { $0 == extra }
            case .custom(let name): profile.customTopics.removeAll { VoiceTextValidator.key($0) == VoiceTextValidator.key(name) }
            }
            profile.topicDetails[topic.id] = nil
            return .removed
        }
        guard profile.topicCount < VoiceLimits.topics else {
            return .limit(VoiceLimits.message(max: VoiceLimits.topics, noun: String(localized: "topics")))
        }
        switch topic {
        case .niche(let niche): profile.niches.append(niche)
        case .extra(let extra): profile.voiceTopics.append(extra)
        case .custom(let name): profile.customTopics.append(name)
        }
        return .added
    }

    /// Taps a topic of any kind.
    @discardableResult
    func toggleTopic(_ topic: VoiceTopicRef) -> VoiceEditResult {
        var updated = profile
        let result = Self.toggle(topic, in: &updated)
        if case .limit = result { return result }
        profile = updated
        return result
    }

    /// Taps one of the subtopics Cue suggests under a topic the creator holds (the English text is the id). Up to `VoiceLimits.details`.
    @discardableResult
    func toggleSubtopic(_ subtopic: String, of topic: VoiceTopicRef) -> VoiceEditResult {
        guard profile.topics.contains(topic) else { return .alreadyThere }
        var updated = profile
        var list = updated.topicDetails[topic.id] ?? []
        let key = VoiceTextValidator.key(subtopic)
        if let index = list.firstIndex(where: { VoiceTextValidator.key($0) == key }) {
            list.remove(at: index)
            updated.topicDetails[topic.id] = list.isEmpty ? nil : list
            profile = updated
            return .removed
        }
        guard list.count < VoiceLimits.details else {
            return .limit(VoiceLimits.message(max: VoiceLimits.details, noun: String(localized: "subtopics")))
        }
        list.append(subtopic)
        updated.topicDetails[topic.id] = list
        profile = updated
        return .added
    }

    /// "+ Add your own" under a topic: text the creator typed, checked like every typed answer. A word of the suggestions picked instead
    /// is kept as Cue's own text, so a different spelling of it is the same subtopic.
    @discardableResult
    func addSubtopic(_ raw: String, to topic: VoiceTopicRef, keepingTyped: Bool = false) -> VoiceEditResult {
        guard profile.topics.contains(topic) else { return .alreadyThere }
        let held = profile.subtopics(of: topic)
        let suggested = topic.suggestedSubtopics
        switch VoiceTextValidator.check(raw, existing: held, vocabulary: keepingTyped ? [] : suggested.map(\.label)) {
        case .tooShort, .tooLong, .blocked: return .rejected(VoiceTextValidator.check(raw, existing: held))
        case .duplicate: return .alreadyThere
        case .typo(let suggestion, let original): return .suggest(suggestion: suggestion, original: original)
        case .accepted(let text):
            if let option = suggested.first(where: { VoiceTextValidator.key($0.label) == VoiceTextValidator.key(text) }) {
                return toggleSubtopic(option.id, of: topic)
            }
            guard held.count < VoiceLimits.details else {
                return .limit(VoiceLimits.message(max: VoiceLimits.details, noun: String(localized: "subtopics")))
            }
            profile.topicDetails[topic.id] = held + [text]
            return .added
        }
    }

    // MARK: - Who is watching

    /// Picks the group that is watching, or clears it. A group sets the vocabulary it implies, and choosing one is answering "Who's watching?".
    func setAudienceGroup(_ group: AudienceGroup?) {
        var updated = profile
        updated.audienceGroup = group
        if let group {
            updated.audienceNote = nil
            updated.vocabulary = group.vocabulary
            updated.confirm(.audience)
        }
        profile = updated
    }

    /// "Describe them in your words": text the creator typed, checked first. An empty text clears the note.
    @discardableResult
    func setAudienceNote(_ raw: String) -> VoiceEditResult {
        setTyped(raw, clear: { $0.audienceNote = nil }, store: {
            $0.audienceNote = $1
            $0.audienceGroup = nil
            $0.confirm(.audience)
        })
    }

    /// Taps why they watch. Up to `WatchReason.limit`.
    @discardableResult
    func toggleWatchReason(_ reason: WatchReason) -> VoiceEditResult {
        var updated = profile
        if let index = updated.watchReasons.firstIndex(of: reason) {
            updated.watchReasons.remove(at: index)
            profile = updated
            return .removed
        }
        guard updated.watchReasons.count < VoiceLimits.watchReasons else {
            return .limit(VoiceLimits.message(max: VoiceLimits.watchReasons, noun: String(localized: "reasons")))
        }
        updated.watchReasons.append(reason)
        profile = updated
        return .added
    }

    // MARK: - What the videos are for

    /// Taps what their videos are for. Up to `ContentGoal.limit`.
    @discardableResult
    func toggleContentGoal(_ goal: ContentGoal) -> VoiceEditResult {
        var updated = profile
        if let index = updated.contentGoals.firstIndex(of: goal) {
            updated.contentGoals.remove(at: index)
            profile = updated
            return .removed
        }
        guard updated.contentGoals.count < VoiceLimits.contentGoals else {
            return .limit(VoiceLimits.message(max: VoiceLimits.contentGoals, noun: String(localized: "goals")))
        }
        updated.contentGoals.append(goal)
        profile = updated
        return .added
    }

    // MARK: - Who is talking

    /// "+ Something else" for the kind of creator: a few words of their own, checked first. The closest of the eight stays, so the
    /// answer still counts and still suggests "I" or "we"; an empty text goes back to the eight.
    @discardableResult
    func setCustomRole(_ raw: String) -> VoiceEditResult {
        setTyped(raw, clear: { $0.customRole = nil }, store: { $0.customRole = $1 })
    }

    /// A short credential ("Registered nurse"): the AI says it only when it is true of them. An empty text clears it.
    @discardableResult
    func setCredential(_ raw: String) -> VoiceEditResult {
        setTyped(raw, clear: { $0.credential = nil }, store: { $0.credential = $1 })
    }

    /// "Scripts say I / We". Nil goes back to what the kind of creator suggests.
    func setSpeaksAs(_ speaksAs: SpeaksAs?) {
        profile.speaksAs = speaksAs
    }

    // MARK: - Helpers

    /// A single answer the creator types: empty clears it, otherwise it is checked (2–40 characters, nothing the model refuses) and kept.
    private func setTyped(
        _ raw: String, clear: (inout CreatorProfile) -> Void, store: (inout CreatorProfile, String) -> Void
    ) -> VoiceEditResult {
        var updated = profile
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clear(&updated)
            profile = updated
            return .removed
        }
        let check = VoiceTextValidator.check(raw)
        guard case .accepted(let text) = check else { return .rejected(check) }
        store(&updated, text)
        profile = updated
        return .added
    }
}

extension CreatorProfileService {
    // MARK: - Where they post

    /// Taps a platform they post on: any number of them, unlike the one-tap question of the tip.
    @discardableResult
    func togglePlatform(_ platform: Platform) -> VoiceEditResult {
        var updated = profile
        if let index = updated.reach.platforms.firstIndex(of: platform) {
            updated.reach.platforms.remove(at: index)
            profile = updated
            return .removed
        }
        updated.reach.platforms.append(platform)
        profile = updated
        return .added
    }

    /// Confirms what an older build saved for a step (the tone or the vocabulary) exactly as it is: the creator saw it and kept it.
    func confirm(_ step: VoiceSetupStep) {
        var updated = profile
        updated.confirm(step)
        profile = updated
    }

    // MARK: - Approved scripts

    /// Takes away something Cue learned from a script the creator approved.
    func removeApprovedSample(_ id: UUID) {
        profile.approvedSamples.removeAll { $0.id == id }
    }
}

extension CreatorProfileService {
    // MARK: - "Sounds like me"

    /// The creator said a script written in their voice sounds like them (plan stage 5): it counts as an approval (two make an example for the meter) and,
    /// when the text can be learned from, its opening is kept on this iPhone as one of the last `VoiceLimits.approvedSamples` approved scripts, which Cue
    /// then sends as examples of how they write. The oldest goes when a fourth comes; they can be removed in Examples, and "Delete my Cue data" clears them.
    /// - Returns: whether a sample was kept (a script with words the model won't learn from, or too short, only counts as an approval).
    @discardableResult
    func recordApproval(of script: String) -> Bool {
        var updated = profile
        updated.approvals += 1
        let sample = Self.approvedSample(from: script)
        if let sample, !updated.approvedSamples.contains(where: { VoiceTextValidator.key($0.text) == VoiceTextValidator.key(sample) }) {
            updated.approvedSamples.append(VoiceExample(text: sample, source: String(localized: "Sounds like me")))
            updated.approvedSamples = Array(updated.approvedSamples.suffix(VoiceLimits.approvedSamples))
        }
        profile = updated
        return sample != nil
    }

    /// What of a script is kept: its first `VoiceExample.sentCharacters` characters, spoken words only (no stage cues), on one line; nil when there is
    /// too little to learn from or it has words the model won't learn from.
    static func approvedSample(from script: String) -> String? {
        let spoken = CueParser.stripCues(script).split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        guard case .accepted(let text) = VoiceTextValidator.checkExample(spoken) else { return nil }
        return String(text.prefix(VoiceExample.sentCharacters))
    }
}
