//
//  ExportReadySheet.swift
//  Cue Studio
//

import SwiftUI

/// "Your video is ready": what the creator sees when they tap Share, Save or the share icon with no free exports left. The video is saved in
/// Takes, nothing is lost; "Export with Cue Pro" opens the calm Pro, which subscribes and exports it, and "Not now" leaves the take as it is.
struct ExportReadySheet: View {
    let take: Take
    /// The free exports with what invites earned.
    var limit = UsagePolicy.freeExports
    let onPro: () -> Void
    let onDecline: () -> Void
    /// "Or invite friends · +3 exports for each friend", while invites are offered (§60).
    var invite: (label: String, action: () -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                TakeThumbnail(take: take)
                    .frame(width: 84, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text("✓ READY")
                            .monoFont(size: 8.5, weight: .heavy)
                            .foregroundStyle(Palette.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .frame(minHeight: 18)
                            .background(Palette.Takes.posterPill, in: Capsule())
                            .padding(6)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
                    .accessibilityHidden(true)
                Text("Your video is ready")
                    .cueFont(22, weight: .bold)
                    .tracking(-0.22)
                    .accessibilityAddTraits(.isHeader)
                Text("Saved in Takes · nothing is lost. You've used your \(limit) free exports.")
                    .cueFont(15)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)
            }
            Button(action: onPro) { Text("Export with Cue Pro").frame(maxWidth: .infinity) }
                .buttonStyle(.cuePrimary())
                .accessibilityIdentifier("exportReady.pro")
            if let invite {
                Button(action: invite.action) {
                    Text(verbatim: invite.label)
                        .cueFont(15, weight: .semibold)
                        .foregroundStyle(Palette.accText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exportReady.invite")
            }
            Button(action: onDecline) { Text("Not now").frame(maxWidth: .infinity, minHeight: Metrics.hitTarget) }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("exportReady.notNow")
        }
        .padding(EdgeInsets(top: 12, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .fittedSheet()
        .presentationBackground(Palette.sheetNight)
    }
}
