//
//  VoiceRoleField.swift
//  Cue Studio
//

import SwiftUI

/// "What kind of creator are you?" (My Cue Voice · Essentials 1, the first question): the long list of kinds with a search and areas
/// (`CreatorKindPicker`) and "+ Something else" for their own words, then what their videos are for (the owner, 03/11/2026: on the same screen,
/// so a lawyer says "win clients" and "raise awareness" right there), each under its own title (`VoiceFieldSection`). How scripts talk about them (I or
/// we, the grammar) is the next step (`VoiceSpeechField`). The same field in the guided questions, the tip's sheet and the editor.
struct VoiceRoleField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    @State private var typesRole = false

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.questionGap) {
            VoiceFieldSection {
                CreatorKindPicker(selected: current.customRole == nil ? current.creatorKind : nil, onPick: pick, identifier: "voiceSetup.role")
                ownRole
            }
            goals
        }
    }

    // MARK: - The list

    private func pick(_ kind: CreatorKind) {
        profile.answer(.role, with: VoiceOption(id: kind.id, label: kind.title))
        typesRole = false
    }

    // MARK: - Their own

    /// "+ Something else": a few words of their own, when no kind in the list is it.
    @ViewBuilder
    private var ownRole: some View {
        if let custom = current.customRole, !typesRole {
            Button {
                typesRole = true
            } label: {
                SelectableCard(isSelected: true, radius: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(custom).cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
                        Text("Your own · tap to change").cueFont(.caption).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(12)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.role.own")
        } else if typesRole {
            VoiceTypedField(
                placeholder: String(localized: "e.g. Wedding photographer, chess coach"),
                submit: { text, _ in profile.setCustomRole(text) }, addLabel: String(localized: "Save"),
                initialText: current.customRole ?? "", clearsWhenAdded: false, identifier: "voice.role.field"
            )
        } else {
            Button {
                typesRole = true
            } label: {
                Text("+ Something else")
                    .cueFont(.body)
                    .foregroundStyle(Palette.aiText)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("voice.role.somethingElse")
        }
    }

    // MARK: - What the videos are for

    private var goals: some View {
        VoiceFieldSection(String(localized: "My videos are for"), detail: String(localized: "up to \(VoiceLimits.contentGoals)")) {
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
