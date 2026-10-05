//
//  VoicePersonalitySheet.swift
//  Cue Studio
//

import SwiftUI

/// The sheet of one Personality row (openings, endings, phrases, formats, swearing): the options as chips, the creator's own
/// words checked as they are added (2–40 characters, no repeats, nothing Apple Intelligence refuses, "Did you mean…"), and
/// the limit said as "Max n".
struct VoicePersonalitySheet: View {
    let item: VoicePersonalityItem

    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var feedback: Feedback?
    @FocusState private var fieldIsFocused: Bool

    private enum Feedback: Equatable {
        case message(String)
        case typo(suggestion: String, original: String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: item.title)
            Text(item.question)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
            switch item {
            case .formats: formatChips
            case .swearing: swearingChoices
            case .openings, .endings, .phrases: tagChips
            }
            if item != .swearing, item != .formats { customField }
            if let feedback { feedbackView(feedback) }
            Button("None of these") {
                profile.decline(item)
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityIdentifier("voice.sheet.none")
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 20, trailing: Metrics.gutter))
        .fittedSheet()
        .accessibilityIdentifier("voice.sheet.\(item.rawValue)")
        .onAppear { fieldIsFocused = item == .phrases }
    }

    // MARK: - Choices

    private var current: [String] { profile.profile.values(for: item) }

    /// The offered options, then what the creator added that isn't one of them.
    private var chips: [String] {
        let own = current.filter { value in !item.options.contains { VoiceTextValidator.key($0) == VoiceTextValidator.key(value) } }
        return item.options + own
    }

    private var tagChips: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(chips, id: \.self) { value in
                let isOn = current.contains { VoiceTextValidator.key($0) == VoiceTextValidator.key(value) }
                Button {
                    Haptics.selection()
                    feedback = nil
                    if case .limit(let message) = profile.toggle(value, for: item) { toast.show(message) }
                } label: { FilterChip(label: value, isSelected: isOn) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voice.option")
            }
        }
    }

    private var formatChips: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(ScriptType.allCases) { format in
                Button {
                    Haptics.selection()
                    if case .limit(let message) = profile.toggle(format: format) { toast.show(message) }
                } label: { FilterChip(label: format.label, isSelected: profile.profile.formats.contains(format)) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voice.format.\(format.rawValue)")
            }
        }
    }

    private var swearingChoices: some View {
        HStack(spacing: 8) {
            ForEach(Swearing.allCases) { choice in
                Button {
                    Haptics.selection()
                    profile.setSwearing(choice)
                } label: { FilterChip(label: choice.label, isSelected: profile.profile.swearing == choice) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voice.swearing.\(choice.rawValue)")
            }
            Text("Strong swearing is never written.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
    }

    // MARK: - Typing

    private var customField: some View {
        HStack(spacing: 10) {
            TextField(String(localized: "Type yours"), text: $typed)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($fieldIsFocused)
                .onSubmit { add() }
                .accessibilityIdentifier("voice.field")
            Button("Add") { add() }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("voice.add")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
    }

    private func add(keepingTyped: Bool = false) {
        switch profile.addCustom(typed, for: item, keepingTyped: keepingTyped) {
        case .added:
            typed = ""
            feedback = nil
        case .alreadyThere:
            // Already there: it stays selected, and the field says so.
            typed = ""
            feedback = .message(String(localized: "Already added."))
        case .limit(let message):
            feedback = nil
            toast.show(message)
        case .rejected(let check):
            feedback = check.message.map(Feedback.message)
        case .suggest(let suggestion, let original):
            feedback = .typo(suggestion: suggestion, original: original)
        case .removed:
            break
        }
    }

    @ViewBuilder
    private func feedbackView(_ feedback: Feedback) -> some View {
        switch feedback {
        case .message(let text):
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.warnText)
                .accessibilityIdentifier("voice.feedback")
        case .typo(let suggestion, let original):
            HStack(spacing: 10) {
                Text("Did you mean “\(suggestion)”?")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Use") {
                    typed = suggestion
                    add()
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("voice.typo.use")
                Button("Keep mine") {
                    typed = original
                    add(keepingTyped: true)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("voice.typo.keep")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("voice.feedback")
        }
    }
}
