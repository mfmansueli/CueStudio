//
//  ExportReadySheet.swift
//  Cue Studio
//

import SwiftUI

/// "Your video is ready": what the creator sees when they tap Share, Save or the share icon with no free exports left. The video is saved in
/// Takes, nothing is lost; the trial exports it now (the calm Pro), "See what's in Pro" shows what Pro is, and "Not now" leaves the take as it is.
struct ExportReadySheet: View {
    let take: Take
    let onTrial: () -> Void
    let onSeePro: () -> Void
    let onDecline: () -> Void

    @Environment(StoreManager.self) private var store

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                TakeThumbnail(take: take)
                    .frame(width: 84, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text("✓ READY")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Palette.success)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(Palette.Takes.posterPill, in: Capsule())
                            .padding(6)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
                    .accessibilityHidden(true)
                Text("Your video is ready")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.22)
                    .accessibilityAddTraits(.isHeader)
                Text("Saved in Takes · nothing is lost. You've used your \(UsagePolicy.freeExports) free exports.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)
            }
            Button(action: onTrial) { Text("Start free trial · export now").frame(maxWidth: .infinity) }
                .buttonStyle(.cuePrimary())
                .accessibilityIdentifier("exportReady.trial")
            Button(action: onSeePro) { Text("See what's in Pro").frame(maxWidth: .infinity) }
                .buttonStyle(.cueSecondary())
                .accessibilityIdentifier("exportReady.seePro")
            Button(action: onDecline) { Text("Not now").frame(maxWidth: .infinity, minHeight: Metrics.hitTarget) }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("exportReady.notNow")
            Text(verbatim: finePrint)
                .font(.footnote)
                .foregroundStyle(Palette.inkHint)
                .multilineTextAlignment(.center)
                .padding(.top, -6)
        }
        .padding(EdgeInsets(top: 12, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
        .fittedSheet()
        .presentationBackground(Palette.sheetNight)
    }

    /// "7 days free, then $39.99/year. Cancel anytime."
    private var finePrint: String {
        let price = store.displayPrice(for: .annual) ?? "$39.99"
        return String(localized: "7 days free, then \(price)/year. Cancel anytime.")
    }
}
