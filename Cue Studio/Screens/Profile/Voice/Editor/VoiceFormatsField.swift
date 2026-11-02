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

    /// The opening or ending tapped last, for its live example.
    @State private var lastTapped: [VoiceQuestion: String] = [:]

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            group(.formats, label: String(localized: "What you film most"), limit: VoiceLimits.formats)
            group(.openings, label: String(localized: "How you like to open"), limit: VoiceLimits.openings)
            // A habit, not a rule (the owner's B11, 02/11/2026): "never" is Avoid's.
            group(
                .endings, label: String(localized: "How you usually end"), limit: VoiceLimits.endings,
                note: String(localized: "What you usually do. To never ask viewers for anything, pick Calls to action under Avoid.")
            )
            goals
        }
    }

    // MARK: - A question of the bank

    private func group(_ question: VoiceQuestion, label: String, limit: Int, note: String? = nil) -> some View {
        let options = question.options
        let extras = typed(for: question, among: options)
        return VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(label, detail: String(localized: "up to \(limit)"))
            if let item = item(for: question) {
                // Openings and endings: "I use" and "I never use" (the owner's item 5).
                VoiceUseNeverChips(
                    question: question, options: options, extras: extras,
                    onTapExtra: { profile.toggle($0, for: item) },
                    onUse: { lastTapped[question] = $0.id }
                )
                Text(question == .endings && current.endings.count > 1
                    ? "Tap again for “I never use”. Touch and hold an ending to make it the main one."
                    : "Tap again for “I never use”.")
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VoiceOptionChips(
                    options: options,
                    isSelected: { profile.isSelected($0, for: question) },
                    onTap: { option in
                        if case .limit(let message) = profile.answer(question, with: option) { toast.show(message, kind: .problem) }
                    },
                    extras: extras,
                    onTapExtra: { profile.removeTypedFormat($0) },
                    identifier: "voice.\(question.rawValue)"
                )
            }
            if let line = example(for: question) {
                VoiceLiveExample(
                    caption: question == .openings
                        ? String(localized: "Example · your scripts open like this") : String(localized: "Example · your scripts end like this"),
                    line: line, identifier: "voice.\(question.rawValue).example"
                )
            }
            VoiceTypedField(
                placeholder: String(localized: "Type yours"),
                submit: { text, keeping in profile.addSomethingElse(text, for: question, keepingTyped: keeping) },
                identifier: "voice.\(question.rawValue).field"
            )
            if let note {
                Text(note)
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("voice.\(question.rawValue).note")
            }
        }
    }

    /// The live example of the openings or the endings (the owner's item 1): the one tapped last, else the last one held.
    private func example(for question: VoiceQuestion) -> String? {
        let held: [String]
        switch question {
        case .openings: held = current.openings
        case .endings: held = current.endings
        default: return nil
        }
        let tapped = lastTapped[question].map(VoiceTextValidator.key)
        guard let stored = held.first(where: { VoiceTextValidator.key($0) == tapped }) ?? held.last else { return nil }
        return question == .openings ? VoiceSampleBuilder.openingExample(stored) : VoiceSampleBuilder.endingExample(stored)
    }

    private func item(for question: VoiceQuestion) -> VoicePersonalityItem? {
        switch question {
        case .openings: .openings
        case .endings: .endings
        default: nil
        }
    }

    /// What the creator typed for a question that isn't one of its options: an opening, an ending or a format (what an older build kept as a
    /// tag shows in "Also true about me").
    private func typed(for question: VoiceQuestion, among options: [VoiceOption]) -> [String] {
        let known = Set(options.flatMap { [VoiceTextValidator.key($0.label), VoiceTextValidator.key($0.id)] })
        switch question {
        case .openings: return current.openings.filter { !known.contains(VoiceTextValidator.key($0)) && !isStyleName($0, among: options) }
        case .endings: return current.endings.filter { !known.contains(VoiceTextValidator.key($0)) && !isStyleName($0, among: options) }
        case .formats: return current.customFormats
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
                    if case .limit(let message) = profile.toggleContentGoal(goal) { toast.show(message, kind: .problem) }
                },
                identifier: "voice.goal"
            )
        }
    }
}
