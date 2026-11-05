//
//  ReadyInviteCard.swift
//  Cue Studio
//

import SwiftUI

/// "Ready to travel" as the free exports run out (DESIGN_PROJECT §60, one ask per moment): with one left, an invite (a friend's first export
/// brings 3 more); with none, Cue Pro first and the invite as the other way. Only on the free plan, so the reward is always exports.
struct ReadyInviteCard: View {
    let left: Int
    let onInvite: () -> Void
    let onPro: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "gift")
                    .cueFont(17, weight: .semibold)
                    .foregroundStyle(Palette.accText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(left == 0 ? "Export more videos" : "Invite a friend")
                        .cueFont(.subheadline, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: left == 0
                        ? String(localized: "Cue Pro exports without limit. Or invite friends: +\(ReferralRewards.exportsPerFriend) exports for each.")
                        : String(localized: "+\(ReferralRewards.exportsPerFriend) exports for each friend who exports their first video with Cue."))
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if left > 0 {
                    Button(action: onInvite) { Text("Invite") }
                        .buttonStyle(.cueSecondary(expands: false))
                        .accessibilityIdentifier("ready.inviteButton")
                }
            }
            if left == 0 {
                HStack(spacing: 10) {
                    Button(action: onPro) { Text("Try Cue Pro") }
                        .buttonStyle(.cuePrimary())
                        .accessibilityIdentifier("ready.proButton")
                    Button(action: onInvite) { Text("Invite friends") }
                        .buttonStyle(.cueSecondary())
                        .accessibilityIdentifier("ready.inviteButton")
                }
            }
        }
        .padding(16)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ready.inviteCard")
    }
}
