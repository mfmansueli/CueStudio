//
//  CreatorProfileService+Never.swift
//  Cue Studio
//

import Foundation

/// How one of Cue's openings or endings is held (the owner's item 5, 02/11/2026).
enum VoiceChoiceState: Equatable {
    case off, uses, never
}

extension CreatorProfileService {
    // MARK: - I use · I never use

    /// "No call to action" has no "never": never asking for anything is Avoid's "Calls to action".
    static func canBeNever(_ id: String, for question: VoiceQuestion) -> Bool {
        question == .openings || (question == .endings && id != "No call to action")
    }

    func choiceState(_ option: VoiceOption, for question: VoiceQuestion) -> VoiceChoiceState {
        if isSelected(option, for: question) { return .uses }
        return never(of: question, in: profile).contains(option.id) ? .never : .off
    }

    /// A tap on one of Cue's openings or endings: off, then "I use", then "I never use", then off again.
    @discardableResult
    func cycle(_ option: VoiceOption, for question: VoiceQuestion) -> VoiceEditResult {
        switch choiceState(option, for: question) {
        case .off:
            return answer(question, with: option)
        case .uses:
            guard Self.canBeNever(option.id, for: question) else { return answer(question, with: option) }
            return markNever(option, for: question)
        case .never:
            var updated = profile
            setNever(never(of: question, in: updated).filter { $0 != option.id }, for: question, in: &updated)
            profile = updated
            return .removed
        }
    }

    /// "I never use" (the menu of a chip, or a second tap): out of what they use, into what they never use.
    @discardableResult
    func markNever(_ option: VoiceOption, for question: VoiceQuestion) -> VoiceEditResult {
        guard Self.canBeNever(option.id, for: question) else { return .alreadyThere }
        let item: VoicePersonalityItem = question == .openings ? .openings : .endings
        var list = never(of: question, in: profile)
        guard !list.contains(option.id) else { return .alreadyThere }
        guard list.count < VoiceLimits.never else { return .limit(String(localized: "Max \(VoiceLimits.never) · tap to remove")) }
        if isSelected(option, for: question) { toggle(option.id, for: item) }
        var updated = profile
        list.append(option.id)
        setNever(list, for: question, in: &updated)
        profile = updated
        return .added
    }

    /// "Make it the main one": the ending a video ends with (the first); the other is for when it doesn't fit.
    func makeMainEnding(_ stored: String) {
        let key = VoiceTextValidator.key(stored)
        guard let index = profile.endings.firstIndex(where: { VoiceTextValidator.key($0) == key }), index > 0 else { return }
        var updated = profile
        updated.endings.insert(updated.endings.remove(at: index), at: 0)
        profile = updated
    }

    private func never(of question: VoiceQuestion, in profile: CreatorProfile) -> [String] {
        question == .openings ? profile.neverOpenings : question == .endings ? profile.neverEndings : []
    }

    private func setNever(_ list: [String], for question: VoiceQuestion, in profile: inout CreatorProfile) {
        if question == .openings { profile.neverOpenings = list } else if question == .endings { profile.neverEndings = list }
    }
}
