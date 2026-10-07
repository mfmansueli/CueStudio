//
//  VoicePhrasesField.swift
//  Cue Studio
//

import SwiftUI

/// Personality · their words: the phrases they actually say (up to five, each one removable) and what Cue never writes (up to three).
struct VoicePhrasesField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            phrases
            avoid
        }
    }

    // MARK: - Phrases

    private var phrases: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "Phrases you actually say"), detail: String(localized: "used sometimes, never in every video"))
            if !current.phrases.isEmpty {
                GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
                    ForEach(current.phrases, id: \.self) { phrase in
                        HStack {
                            Text("“\(phrase)”").font(.body).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
                            Button { profile.removePhrase(phrase) } label: {
                                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Palette.ink2)
                                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                            }
                            .accessibilityLabel(Text("Remove \(phrase)"))
                            .accessibilityIdentifier("voice.phrase.remove")
                        }
                        .padding(.leading, 16)
                        .frame(minHeight: 48)
                    }
                }
            }
            VoiceTypedField(
                placeholder: String(localized: "e.g. Okay, real talk."),
                submit: { text, keeping in profile.addSomethingElse(text, for: .phrases, keepingTyped: keeping) },
                identifier: "voice.phrases.field"
            )
        }
    }

    // MARK: - What Cue never writes

    private var avoid: some View {
        let options = VoiceQuestion.avoid.options
        let known = Set(options.map { VoiceTextValidator.key($0.id) })
        let typed = current.avoid.filter { !known.contains(VoiceTextValidator.key($0)) }
        return VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "Cue never writes"), detail: String(localized: "up to \(VoiceLimits.avoid)"))
            VoiceOptionChips(
                options: options,
                isSelected: { profile.isSelected($0, for: .avoid) },
                onTap: { option in
                    if case .limit(let message) = profile.answer(.avoid, with: option) { toast.show(message) }
                },
                extras: typed,
                onTapExtra: { value in profile.answer(.avoid, with: VoiceOption(id: value, label: value)) },
                identifier: "voice.avoid"
            )
            VoiceTypedField(
                placeholder: String(localized: "e.g. Brand names"),
                submit: { text, keeping in profile.addSomethingElse(text, for: .avoid, keepingTyped: keeping) },
                identifier: "voice.avoid.field"
            )
        }
    }
}
