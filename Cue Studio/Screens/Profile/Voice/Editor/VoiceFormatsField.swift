//
//  VoiceFormatsField.swift
//  Cue Studio
//

import SwiftUI

/// Personality · how their videos work: what they film most, how they like to open and how they usually end, and what the videos are for. One
/// field in the editor; each group is a question of the bank, answered the same way as in the tip.
struct VoiceFormatsField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            group(.formats, label: String(localized: "What you film most"), limit: VoiceLimits.formats)
            group(.openings, label: String(localized: "How you like to open"), limit: VoiceLimits.openings)
            group(.endings, label: String(localized: "How you usually end"), limit: VoiceLimits.endings)
            goals
        }
    }

    // MARK: - A question of the bank

    private func group(_ question: VoiceQuestion, label: String, limit: Int) -> some View {
        let options = question.options
        let extras = typed(for: question, among: options)
        return VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(label, detail: String(localized: "up to \(limit)"))
            VoiceOptionChips(
                options: options,
                isSelected: { profile.isSelected($0, for: question) },
                onTap: { option in
                    if case .limit(let message) = profile.answer(question, with: option) { toast.show(message) }
                },
                extras: extras,
                onTapExtra: { value in
                    if let item = item(for: question) { profile.toggle(value, for: item) }
                },
                identifier: "voice.\(question.rawValue)"
            )
            VoiceTypedField(
                placeholder: String(localized: "Type yours"),
                submit: { text, keeping in profile.addSomethingElse(text, for: question, keepingTyped: keeping) },
                identifier: "voice.\(question.rawValue).field"
            )
        }
    }

    private func item(for question: VoiceQuestion) -> VoicePersonalityItem? {
        switch question {
        case .openings: .openings
        case .endings: .endings
        default: nil
        }
    }

    /// What the creator typed for a question that isn't one of its options (an opening or an ending, or a tag for a format).
    private func typed(for question: VoiceQuestion, among options: [VoiceOption]) -> [String] {
        let known = Set(options.flatMap { [VoiceTextValidator.key($0.label), VoiceTextValidator.key($0.id)] })
        switch question {
        case .openings: return current.openings.filter { !known.contains(VoiceTextValidator.key($0)) && !isStyleName($0, among: options) }
        case .endings: return current.endings.filter { !known.contains(VoiceTextValidator.key($0)) && !isStyleName($0, among: options) }
        case .formats:
            let formatTags = Set(VoiceQuestion.formatTags.values.map(VoiceTextValidator.key))
            return current.customTags.filter { !formatTags.contains(VoiceTextValidator.key($0)) && !known.contains(VoiceTextValidator.key($0)) }
        default: return []
        }
    }

    private func isStyleName(_ text: String, among options: [VoiceOption]) -> Bool {
        options.contains { VoiceTextValidator.key($0.label) == VoiceTextValidator.key(text) }
    }

    // MARK: - What the videos are for

    private var goals: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "My videos are for"), detail: String(localized: "up to \(VoiceLimits.contentGoals)"))
            VoiceOptionChips(
                options: ContentGoal.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) },
                isSelected: { option in current.contentGoals.contains { $0.rawValue == option.id } },
                onTap: { option in
                    guard let goal = ContentGoal(rawValue: option.id) else { return }
                    if case .limit(let message) = profile.toggleContentGoal(goal) { toast.show(message) }
                },
                identifier: "voice.goal"
            )
        }
    }
}
