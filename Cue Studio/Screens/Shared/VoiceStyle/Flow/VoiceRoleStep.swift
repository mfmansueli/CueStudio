//
//  VoiceRoleStep.swift
//  Cue Studio
//

import SwiftUI

/// "What kind of creator are you?": eight cards, two across. Picking one moves on.
struct VoiceRoleStep: View {
    let draft: VoiceSetupDraft
    let onPick: (CreatorRole) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(CreatorRole.allCases) { role in
                Button { onPick(role) } label: {
                    SelectableCard(isSelected: draft.isPicked(role), radius: 16) {
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
        }
    }
}
