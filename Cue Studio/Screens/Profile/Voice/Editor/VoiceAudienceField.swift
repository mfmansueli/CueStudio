//
//  VoiceAudienceField.swift
//  Cue Studio
//

import SwiftUI

/// "Who's watching?" (Essentials 3): the people (eight groups, the likeliest for their kind of creator first, or their own words), why they watch
/// (up to two) and how much they already know. The same field in the guided questions and in the editor.
struct VoiceAudienceField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    @State private var typesAudience = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                VoiceFieldLabel(String(localized: "Who is watching?"))
                people
                ownWords
            }
            VStack(alignment: .leading, spacing: 8) {
                VoiceFieldLabel(String(localized: "Why do they watch you?"), detail: String(localized: "up to \(VoiceLimits.watchReasons) · shapes the hook and the payoff"))
                VoiceOptionChips(
                    options: WatchReason.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) },
                    isSelected: { option in current.watchReasons.contains { $0.rawValue == option.id } },
                    onTap: { option in
                        guard let reason = WatchReason(rawValue: option.id) else { return }
                        if case .limit(let message) = profile.toggleWatchReason(reason) { toast.show(message) }
                    },
                    identifier: "voice.watch"
                )
            }
            level
        }
    }

    // MARK: - The people

    private var people: some View {
        GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
            ForEach(AudienceGroup.ordered(for: current.role)) { group in
                let picked = current.audienceNote == nil && current.audienceGroup == group
                VoiceChoiceRow(
                    title: group.label, isOn: picked, identifier: "voiceSetup.audience.\(group.rawValue)"
                ) {
                    typesAudience = false
                    profile.setAudienceGroup(group)
                }
            }
        }
    }

    /// "Describe them in your words": what the creator typed replaces the group.
    @ViewBuilder
    private var ownWords: some View {
        if let note = current.audienceNote, !typesAudience {
            Button { typesAudience = true } label: {
                SelectableCard(isSelected: true, radius: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text("Your own · tap to change").font(.caption).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(12)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.audience.own")
        } else if typesAudience {
            VoiceTypedField(
                placeholder: String(localized: "e.g. Nurses on night shifts"),
                submit: { text, _ in profile.setAudienceNote(text) }, addLabel: String(localized: "Save"),
                initialText: current.audienceNote ?? "", clearsWhenAdded: false, identifier: "voice.audience.field"
            )
        } else {
            Button { typesAudience = true } label: {
                Text("+ Describe them in your words")
                    .font(.body)
                    .foregroundStyle(Palette.aiText)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.audience.somethingElse")
        }
    }

    // MARK: - How much they know

    private var level: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "How much do they already know?"))
            VoiceSegmentedChoice(
                values: AudienceLevel.allCases, selection: current.audienceLevel, label: \.label,
                onPick: { profile.answerAudienceLevel($0) }, identifier: "voiceSetup.level"
            )
            if let level = current.audienceLevel {
                Text(level.explanation)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)
            }
        }
    }
}
