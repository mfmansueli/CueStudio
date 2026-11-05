//
//  ProfileInviteRow.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · "Invite friends" (DESIGN_PROJECT §60): always there while invites are offered, with what they earned ("2 of 5 friends · +6 exports")
/// or, before any friend, what one earns ("+3 exports for each friend"). Opens the invites.
struct ProfileInviteRow: View {
    let onOpen: () -> Void

    @Environment(ReferralService.self) private var referral

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: "gift")
                    .cueFont(18, weight: .semibold)
                    .foregroundStyle(Palette.accText)
                    .frame(width: 40, height: 40)
                    .background(Palette.fill, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Invite friends")
                        .cueFont(16, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: detail)
                        .monoFont(size: 11, weight: .semibold)
                        .foregroundStyle((referral.status?.rewarded ?? 0) > 0 ? Palette.accText : Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .cueFont(.footnote, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .frame(minHeight: 60)
            .profileBlock()
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.inviteRow")
    }

    private var detail: String {
        guard referral.isOffered else { return String(localized: "Have a friend’s code? Type it here.") }
        guard let status = referral.status, status.rewarded > 0 else { return InviteCopy.perFriend(referral.reward) }
        return InviteCopy.progress(rewarded: status.rewarded, limit: status.limit, rewards: referral.rewards)
    }
}
