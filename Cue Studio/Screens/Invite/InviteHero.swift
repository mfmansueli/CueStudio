//
//  InviteHero.swift
//  Cue Studio
//

import SwiftUI

/// The top of the invites: the orbit with a planet for each friend who counted, what one friend brings in large ("+3 exports", "+5 Ultra AI
/// scripts" in violet on Pro), for whom, and the count so far ("2 of 5 friends · +6 exports"). With every friend counted: what they brought
/// and a thank-you.
struct InviteHero: View {
    let reward: ReferralReward
    let status: ReferralStatus?
    let rewards: ReferralRewards

    @Environment(PersonalizationService.self) private var personalization

    private var limit: Int { status?.limit ?? ReferralRewards.friendsRewarded }
    private var rewarded: Int { status?.rewarded ?? 0 }
    private var isComplete: Bool { status?.hasReachedLimit == true }
    private var tint: Color { reward == .ultraScripts ? Palette.aiText : Palette.accText }

    var body: some View {
        VStack(spacing: 0) {
            InviteOrbit(friends: rewarded, limit: limit, core: personalization.coreColor, planet: tint)
            Text(verbatim: InviteCopy.headline(reward, rewards: rewards, isComplete: isComplete))
                .cueFont(44, weight: .heavy)
                .tracking(-0.8)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("invite.headline")
            Text(verbatim: isComplete
                ? String(localized: "That’s all \(limit) friends. Thank you for sharing Cue.")
                : String(localized: "for each friend who exports their first video"))
                .cueFont(17)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            Text(verbatim: InviteCopy.progress(rewarded: rewarded, limit: limit, rewards: rewards))
                .monoFont(size: 12, weight: .semibold)
                .interfaceTracking(0.5)
                .foregroundStyle(rewarded > 0 ? tint : Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.top, 14)
                .accessibilityIdentifier("invite.progress")
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: rewarded)
    }
}
