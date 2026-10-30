//
//  PaywallView.swift
//  Cue Studio
//

import SwiftUI

/// Cue Pro (11.4): two subscriptions, with no free trial. Opens from the Profile's plan card and Settings, with the opening (`ProOpening`) and
/// the plans (`ProPlansScreen`); or, when the free exports have run out and a video is waiting, as the calm Pro (the same plans, without the
/// opening's motion); the same calm Pro when Ultra AI's free scripts are used up. Never while recording. Full screen, dismissible from the close
/// button in its navigation bar, always offers Restore.
struct PaywallView: View {
    let context: PaywallContext
    var onPurchased: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(PersonalizationService.self) private var personalization
    /// Where the content starts (under the navigation bar) and the screen's size, read from the background (the one layer that spans the
    /// whole screen).
    @State private var topInset: CGFloat = 0
    @State private var screen = CGSize(width: 393, height: 852)

    var body: some View {
        // A navigation stack of its own: the close button is the system's, in the bar's Liquid Glass.
        NavigationStack {
            ZStack {
                background
                switch context {
                case .profile:
                    ProOpening(plays: true, coreY: layout.galaxyY) { time in
                        ProPlansScreen(context: context, layout: layout, time: time, topInset: topInset) { onPurchased?() }
                    }
                case .export, .ultra:
                    ProOpening(plays: false, coreY: layout.galaxyY) { _ in
                        ProPlansScreen(context: context, layout: layout, topInset: topInset) { onPurchased?() }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // The app's light ink wherever the Pro opens from (the Profile's tint is gold).
                    Button(role: .close) { dismiss() }
                        .tint(Palette.ink)
                        .accessibilityLabel(Text("Close"))
                        .accessibilityIdentifier("paywall.closeButton")
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private var layout: ProLayout { ProLayout(screen: screen, calm: context != .profile) }

    /// The board's night: the haze falls from the top, behind the galaxy, with the sky over it.
    private var background: some View {
        ZStack {
            BgWash(lights: BgWash.pro, base: Palette.bg)
            StarfieldView(density: personalization.sky)
        }
        .ignoresSafeArea()
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
        // Its size is the safe area's (under the bar, above the home indicator); the screen adds the insets back.
        .onGeometryChange(for: CGSize.self) { proxy in
            let insets = proxy.safeAreaInsets
            return CGSize(width: proxy.size.width + insets.leading + insets.trailing, height: proxy.size.height + insets.top + insets.bottom)
        } action: { screen = $0 }
    }
}

#if DEBUG
#Preview {
    PaywallView(context: .profile)
        .previewEnvironment()
}
#endif
