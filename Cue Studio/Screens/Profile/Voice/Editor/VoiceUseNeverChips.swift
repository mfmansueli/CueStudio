//
//  VoiceUseNeverChips.swift
//  Cue Studio
//

import SwiftUI

/// Cue's openings or endings as chips with three states (the owner's item 5, 02/11/2026): a tap puts one in ("I use", ✓), a second makes it
/// "I never use" (✕), a third takes it out. Touch and hold gives the same choices and, on one of two endings they use, "Make it the main one":
/// a video ends with the main one. What they typed shows after Cue's options, used; a tap takes it out.
struct VoiceUseNeverChips: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    let question: VoiceQuestion
    let options: [VoiceOption]
    var extras: [String] = []
    var onTapExtra: (String) -> Void = { _ in }
    /// An option put in ("I use"), for its live example.
    var onUse: (VoiceOption) -> Void = { _ in }

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 4) {
            ForEach(options) { chip($0) }
            ForEach(extras, id: \.self) { value in
                Button {
                    Haptics.selection()
                    onTapExtra(value)
                } label: {
                    FilterChip(label: value, isSelected: true, systemImage: "checkmark")
                        .frame(minHeight: Metrics.hitTarget)
                        .fixedSize()
                }
                .buttonStyle(.cuePress)
                .accessibilityIdentifier("voice.\(question.rawValue).typed")
            }
        }
    }

    private func chip(_ option: VoiceOption) -> some View {
        let state = profile.choiceState(option, for: question)
        let isMain = isMainEnding(option)
        return Button {
            Haptics.selection()
            show(profile.cycle(option, for: question), for: option)
        } label: {
            FilterChip(
                label: isMain ? String(localized: "\(option.label) · Main") : option.label,
                isSelected: state == .uses,
                systemImage: state == .uses ? "checkmark" : state == .never ? "xmark" : nil
            )
            .frame(minHeight: Metrics.hitTarget)
            .fixedSize()
        }
        .buttonStyle(.cuePress)
        .contextMenu { menu(option, state: state, isMain: isMain) }
        .accessibilityValue(Text(stateName(state)))
        .accessibilityIdentifier("voice.\(question.rawValue).\(option.id)")
    }

    @ViewBuilder
    private func menu(_ option: VoiceOption, state: VoiceChoiceState, isMain: Bool) -> some View {
        if state != .uses {
            Button("I use", systemImage: "checkmark") {
                if state == .never { profile.cycle(option, for: question) }
                show(profile.cycle(option, for: question), for: option)
            }
        }
        if state != .never, CreatorProfileService.canBeNever(option.id, for: question) {
            Button("I never use", systemImage: "xmark") { show(profile.markNever(option, for: question), for: option) }
        }
        if question == .endings, state == .uses, !isMain, profile.profile.endings.count > 1 {
            Button("Make it the main one", systemImage: "star") { profile.makeMainEnding(option.id) }
        }
    }

    /// The first of two endings they use is the one a video ends with.
    private func isMainEnding(_ option: VoiceOption) -> Bool {
        let endings = profile.profile.endings
        guard question == .endings, endings.count > 1, let first = endings.first else { return false }
        return VoiceTextValidator.key(first) == VoiceTextValidator.key(option.id)
    }

    private func show(_ result: VoiceEditResult, for option: VoiceOption) {
        if case .limit(let message) = result { toast.show(message, kind: .problem) }
        if result == .added, profile.choiceState(option, for: question) == .uses { onUse(option) }
    }

    private func stateName(_ state: VoiceChoiceState) -> String {
        switch state {
        case .off: ""
        case .uses: String(localized: "I use")
        case .never: String(localized: "I never use")
        }
    }
}
