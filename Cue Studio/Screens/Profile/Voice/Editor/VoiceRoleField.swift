//
//  VoiceRoleField.swift
//  Cue Studio
//

import SwiftUI

/// "What kind of creator are you?" (My Cue Voice · Essentials 1): the eight kinds as cards, "+ Something else" for their own words, a short
/// credential, and "Scripts say I / We". The same field in the guided questions and in the editor.
struct VoiceRoleField: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast

    @State private var typesRole = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CreatorRole.allCases) { role in card(role) }
            }
            ownRole
            VoiceFieldLabel(String(localized: "Scripts say"))
            VoiceSegmentedChoice(
                values: SpeaksAs.allCases, selection: current.resolvedSpeaksAs, label: \.label,
                onPick: { profile.setSpeaksAs($0) }, identifier: "voice.speaksAs"
            )
            Text("“We” for a business, a brand or a team. Doing more than one? Pick the one you film most.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
            if showsCredential { credential }
        }
    }

    // MARK: - The eight

    private func card(_ role: CreatorRole) -> some View {
        Button {
            Haptics.selection()
            profile.answer(.role, with: VoiceOption(id: role.rawValue, label: role.label))
            typesRole = false
        } label: {
            SelectableCard(isSelected: current.role == role && current.customRole == nil, radius: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: role.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.accText)
                        .frame(width: 34, height: 34)
                        .background(Palette.accSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(role.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(role.examples)
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                .padding(12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voiceSetup.role.\(role.id)")
    }

    // MARK: - Their own

    /// "+ Something else": a few words of their own, when none of the eight is it. The closest of the eight can stay picked beside it.
    @ViewBuilder
    private var ownRole: some View {
        if let custom = current.customRole, !typesRole {
            Button {
                typesRole = true
            } label: {
                SelectableCard(isSelected: true, radius: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(custom).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text("Your own · tap to change").font(.caption).foregroundStyle(Palette.ink2)
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
                    .font(.body)
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

    // MARK: - Credential

    /// A short credential, for the kinds of creator whose word carries one ("Registered nurse"). Optional.
    private var showsCredential: Bool {
        current.customRole != nil || current.role == .expert || current.role == .educator
    }

    private var credential: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "Your credential"), detail: String(localized: "optional"))
            VoiceTypedField(
                placeholder: String(localized: "e.g. Registered nurse"),
                submit: { text, _ in profile.setCredential(text) }, addLabel: String(localized: "Save"),
                initialText: current.credential ?? "", clearsWhenAdded: false, identifier: "voice.credential"
            )
            Text("Cue says it only where it is true of you, and never invents another.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }
}
