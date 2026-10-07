//
//  CreatorProfileService+Personality.swift
//  Cue Studio
//

import Foundation

/// What an edit of the Personality or Proof layers did (04 · F9): the sheets turn it into a toast, a chip selected or a
/// "Did you mean" line.
enum VoiceEditResult: Equatable {
    case added
    case removed
    /// Already there: it is selected, nothing is added again.
    case alreadyThere
    /// One more would go over the limit.
    case limit(String)
    /// The text can't be used (too short or long, or a word the AI refuses).
    case rejected(VoiceTextCheck)
    /// Looks like a typo of `suggestion`: "Use" it or "Keep mine" (`keepingTyped`).
    case suggest(suggestion: String, original: String)
}

extension CreatorProfileService {
    // MARK: - Openings, endings and phrases

    /// Taps one of the offered options: puts it in, or takes it out. Over the limit nothing is added.
    @discardableResult
    func toggle(_ value: String, for item: VoicePersonalityItem) -> VoiceEditResult {
        var updated = profile
        let key = VoiceTextValidator.key(value)
        var list = values(of: item, in: updated)
        if let index = list.firstIndex(where: { VoiceTextValidator.key($0) == key }) {
            list.remove(at: index)
            set(list, for: item, in: &updated)
            profile = updated
            return .removed
        }
        guard list.count < item.limit else { return .limit(item.limitMessage) }
        list.append(value)
        set(list, for: item, in: &updated)
        updated.declinedVoiceItems.remove(item)
        profile = updated
        return .added
    }

    /// "+ Something else": text the creator typed. Checked first; `keepingTyped` skips the "did you mean" once the creator
    /// chose "Keep mine".
    @discardableResult
    func addCustom(_ raw: String, for item: VoicePersonalityItem, keepingTyped: Bool = false) -> VoiceEditResult {
        let existing = values(of: item, in: profile)
        switch VoiceTextValidator.check(raw, existing: existing, vocabulary: keepingTyped ? [] : item.options) {
        case .tooShort, .tooLong, .blocked:
            return .rejected(VoiceTextValidator.check(raw, existing: existing))
        case .duplicate:
            return .alreadyThere
        case .typo(let suggestion, let original):
            return .suggest(suggestion: suggestion, original: original)
        case .accepted(let text):
            if existing.contains(where: { VoiceTextValidator.key($0) == VoiceTextValidator.key(text) }) { return .alreadyThere }
            guard existing.count < item.limit else { return .limit(item.limitMessage) }
            var updated = profile
            var list = existing
            list.append(text)
            set(list, for: item, in: &updated)
            if !item.options.contains(where: { VoiceTextValidator.key($0) == VoiceTextValidator.key(text) }),
               !updated.customTags.contains(where: { VoiceTextValidator.key($0) == VoiceTextValidator.key(text) }) {
                updated.customTags.append(text)
            }
            updated.declinedVoiceItems.remove(item)
            profile = updated
            return .added
        }
    }

    // MARK: - Formats, swearing, "None of these"

    @discardableResult
    func toggle(format: ScriptType) -> VoiceEditResult {
        var updated = profile
        if let index = updated.formats.firstIndex(of: format) {
            updated.formats.remove(at: index)
            profile = updated
            return .removed
        }
        guard updated.formats.count + updated.formatTags.count < VoiceLimits.formats else { return .limit(VoicePersonalityItem.formats.limitMessage) }
        updated.formats.append(format)
        updated.declinedVoiceItems.remove(.formats)
        profile = updated
        return .added
    }

    func setSwearing(_ swearing: Swearing?) {
        var updated = profile
        updated.swearing = swearing
        if swearing != nil { updated.declinedVoiceItems.remove(.swearing) }
        profile = updated
    }

    /// "None of these": the question is not asked again, and nothing is filled in.
    func decline(_ item: VoicePersonalityItem) {
        profile.declinedVoiceItems.insert(item)
    }

    // MARK: - Examples (Proof)

    /// Adds something the creator wrote (a caption, a post, a past script). Up to three; nothing with words the model won't learn.
    @discardableResult
    func addExample(_ raw: String, source: String? = nil) -> VoiceEditResult {
        switch VoiceTextValidator.checkExample(raw) {
        case .tooShort: return .rejected(.tooShort)
        case .blocked: return .rejected(.blocked)
        case .accepted(let text):
            guard profile.examples.count < VoiceExample.limit else {
                return .limit(VoiceLimits.message(max: VoiceExample.limit, noun: String(localized: "examples")))
            }
            guard !profile.examples.contains(where: { VoiceTextValidator.key($0.text) == VoiceTextValidator.key(text) }) else { return .alreadyThere }
            profile.examples.append(VoiceExample(text: text, source: source))
            return .added
        }
    }

    func removeExample(_ id: UUID) {
        profile.examples.removeAll { $0.id == id }
    }

    // MARK: - Helpers

    private func values(of item: VoicePersonalityItem, in profile: CreatorProfile) -> [String] {
        switch item {
        case .openings: profile.openings
        case .endings: profile.endings
        case .phrases: profile.phrases
        case .formats, .swearing: []
        }
    }

    private func set(_ list: [String], for item: VoicePersonalityItem, in profile: inout CreatorProfile) {
        switch item {
        case .openings: profile.openings = list
        case .endings: profile.endings = list
        case .phrases: profile.phrases = list
        case .formats, .swearing: break
        }
    }
}
