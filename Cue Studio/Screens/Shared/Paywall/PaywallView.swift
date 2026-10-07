//
//  PaywallView.swift
//  Cue Studio
//

import SwiftUI

/// Cue Pro (11.4): two subscriptions, each starting with a 7-day free trial. Opens from the Profile's plan card and Settings, with the opening
/// (`ProOpening`) and the system's `SubscriptionStoreView` (`ProStoreView`); or, when the free exports have run out and a video is waiting, as
/// the calm Pro (`ProCalmView`). Never while recording. Full screen, dismissible from the close button in its navigation bar, always offers
/// Restore.
struct PaywallView: View {
    let context: PaywallContext
    var onPurchased: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(PersonalizationService.self) private var personalization
    /// Where the content starts (under the navigation bar), read from the background (the one layer that spans the whole screen).
    @State private var topInset: CGFloat = 0
    /// Where the safe area starts without the navigation bar (the status bar's height).
    @State private var statusInset: CGFloat = 0

    /// The planet that is you sits here, from the top of the screen.
    private static let planetY: CGFloat = 100

    var body: some View {
        // A navigation stack of its own: the close button is the system's, in the bar's Liquid Glass.
        NavigationStack {
            ZStack {
                background
                switch context {
                case .profile:
                    ProOpening(plays: true, planetY: Self.planetY) { time in
                        ProPlansScreen(context: context, time: time, topInset: topInset, barHeight: barHeight) { onPurchased?() }
                    }
                case .export:
                    ProOpening(plays: false, planetY: Self.planetY) { _ in
                        ProPlansScreen(context: context, topInset: topInset, barHeight: barHeight) { onPurchased?() }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                        .accessibilityLabel(Text("Close"))
                        .accessibilityIdentifier("paywall.closeButton")
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { statusInset = $0 }
    }

    /// The navigation bar's height: the board's layout is measured from under the status bar, so the copy gives this room back.
    private var barHeight: CGFloat { max(0, topInset - statusInset) }

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
