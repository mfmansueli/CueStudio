//
//  PaywallView.swift
//  Cue Studio
//

import SwiftUI

/// Cue Pro (11.4): two subscriptions, each starting with a 7-day free trial. Opens from the Profile's plan card and Settings, with the opening
/// (`ProOpening`) and the system's `SubscriptionStoreView` (`ProStoreView`); or, when the free exports have run out and a video is waiting, as
/// the calm Pro (`ProCalmView`). Never while recording. Full screen, dismissible, always offers Restore.
struct PaywallView: View {
    let context: PaywallContext
    var onPurchased: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(PersonalizationService.self) private var personalization
    /// Where the safe area starts, read from the background (the one layer that spans the whole screen).
    @State private var topInset: CGFloat = 0

    /// The planet that is you sits here, from the top of the screen.
    private static let planetY: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            switch context {
            case .profile:
                ProOpening(plays: true, planetY: Self.planetY) { time in
                    ProPlansScreen(context: context, time: time, topInset: topInset) { onPurchased?() }
                }
            case .export:
                ProOpening(plays: false, planetY: Self.planetY) { _ in
                    ProPlansScreen(context: context, topInset: topInset) { onPurchased?() }
                }
            }
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.cueIcon(.glass, diameter: 30))
                .padding(.trailing, Metrics.gutter)
                .padding(.top, 0)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("paywall.closeButton")
        }
        .foregroundStyle(Palette.ink)
    }

    /// The board's night: the haze falls from the top, behind the planet that is you, with the sky over it.
    private var background: some View {
        ZStack {
            BgWash(lights: BgWash.pro, base: Palette.bg)
            StarfieldView(density: personalization.sky)
        }
        .ignoresSafeArea()
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
    }
}

#if DEBUG
#Preview {
    PaywallView(context: .profile)
        .previewEnvironment()
}
#endif
