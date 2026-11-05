//
//  InviteSteps.swift
//  Cue Studio
//

import SwiftUI

/// How an invite works, as three short lines on a thin path, each with its sign: share the code, the friend types it, their first export
/// brings the reward.
struct InviteSteps: View {
    let reward: ReferralReward

    /// The sign's circle grows with the text.
    @ScaledMetric(relativeTo: .body) private var badge: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            step("square.and.arrow.up", String(localized: "Share your code"), isLast: false)
            step("keyboard", String(localized: "Your friend types it in Cue before their first export"), isLast: false)
            step("gift", InviteCopy.rewardStep(reward), isLast: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func step(_ symbol: String, _ text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .cueFont(15, weight: .semibold)
                .foregroundStyle(isLast ? Palette.accInk : Palette.ink)
                .frame(width: badge, height: badge)
                .background(isLast ? Palette.acc : Palette.fill, in: Circle())
                .frame(maxHeight: .infinity, alignment: .top)
                .background(alignment: .top) {
                    if !isLast {
                        Rectangle().fill(Palette.fill).frame(width: 1.5).padding(.top, badge)
                    }
                }
                .accessibilityHidden(true)
            Text(verbatim: text)
                .cueFont(16, weight: isLast ? .semibold : .regular)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, badge * 0.22)
                .padding(.bottom, isLast ? 0 : 22)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
