//
//  ProPlansScreen.swift
//  Cue Studio
//

import StoreKit
import SwiftUI

/// Cue Pro, as the owner's canvas draws it (11.4, 30/10/2026): the galaxy (`ProGalaxyArt`), the eyebrow, the title and the line under it, the two
/// highlights and the plain list (`ProMarketing`), the two plans side by side, the yellow button, the small print and Restore · Terms · Privacy;
/// everything fits without scrolling from the SE to the Pro Max (`ProLayout`). The same screen for all three: the regular Pro ("CUE PRO", after
/// the opening) and the calm ones ("YOUR VIDEO IS READY" when the free exports ran out, "ULTRA AI" when its free scripts did). Picking a plan
/// lights the galaxy's ring: the whole year for Yearly, this month for Monthly. Subscribing plays the galaxy's finish, then the Pro goes away
/// with the welcome. The system's `SubscriptionStoreView` can't be drawn like this, so the plans, the button and the small print are Cue's own,
/// over StoreKit 2 (`StoreManager`). There is no free trial (owner, 30/10/2026): trying Cue is its free exports and Ultra AI scripts.
struct ProPlansScreen: View {
    let context: PaywallContext
    var layout = ProLayout.regular
    /// The second of the opening (`ProOpeningScript`); the end of it shows everything in place.
    var time = ProOpeningScript.settled
    /// How far down the screen the content starts (under the navigation bar): the galaxy and the words are placed from the top of the screen.
    var topInset: CGFloat = 0
    let onPurchased: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(AIStatus.self) private var aiStatus
    @Environment(UltraScriptService.self) private var ultra
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var selectedPlan: ProPlan = .annual
    @State private var ring = ProGalaxyArt.RingLight(lit: 12, was: 12, since: .distantPast)
    @State private var finishedAt: Date?
    @State private var isRestoring = false
    /// Apple's sheet for an offer code (a launch or a creator's code); a code that unlocks Pro comes back through the store's updates.
    @State private var redeemsCode = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ProMarketing(context: context, layout: layout, aiIsAvailable: aiStatus.isAvailable, ultraIsOffered: ultra.isAvailable, time: time)
                    .padding(.top, max(0, layout.contentY - topInset))
                    .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // The galaxy, above the title, its core `layout.galaxyY` from the top of the screen.
            .overlay(alignment: .top) {
                let height = ProGalaxyArt.height(radius: layout.galaxyRadius)
                ProGalaxyArt(style: galaxyStyle, radius: layout.galaxyRadius, ring: ring, time: time, finishedAt: finishedAt)
                    .frame(height: height)
                    .offset(y: layout.galaxyY - topInset - height / 2)
            }
            // The footer (the plans, the button and the small print) stops growing at a large size: at the biggest it left no room above it.
            footer.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .task { await store.loadProducts() }
        .onChange(of: selectedPlan) { _, plan in light(for: plan) }
        // Pro arriving while the paywall is open (Ask to Buy approved, a purchase finished elsewhere) completes it in every context, so a
        // video waiting behind it carries on; Restore says its own word instead.
        .onChange(of: store.tier.isPro) { _, isPro in
            if isPro, !isRestoring { complete() }
        }
        .alert("Purchase", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var galaxyStyle: ProGalaxyArt.Style {
        switch context {
        case .profile: .pro
        case .export: .export
        case .ultra: .ultra
        }
    }

    // MARK: - Footer

    private var footer: some View {
        let price = store.displayPrice(for: selectedPlan)
        return VStack(spacing: 0) {
            ProPlanRow {
                ForEach(ProPlan.allCases) { plan in
                    ProPlanCard(
                        plan: plan,
                        detail: plan == .annual ? yearlyDetail : PaywallCopy.price(for: plan, displayPrice: store.displayPrice(for: plan)),
                        badge: plan == .annual ? PaywallCopy.savingsBadge(percent: store.annualSavingsPercent) : nil,
                        isSelected: selectedPlan == plan, height: layout.planHeight, isCompact: layout.isCompact, selection: selection, time: time
                    ) { pick(plan) }
                }
            }
            .padding(.top, layout.footerTop)
            .revealed(.plans, at: time)
            Button {
                Task { await purchase() }
            } label: {
                if store.purchasingPlan != nil {
                    ProgressView().tint(Palette.accInk)
                } else {
                    Text(PaywallCopy.callToAction(for: selectedPlan, displayPrice: price, context: context))
                        .fontWeight(.bold)
                }
            }
            .buttonStyle(.cuePrimary(layout.isCompact ? .regular : .large))
            .shadow(color: Palette.acc.opacity(0.3), radius: 22)
            .shineSweep(interval: 3.6)
            .disabled(price == nil || store.purchasingPlan != nil || finishedAt != nil)
            .padding(.top, layout.buttonGap)
            .accessibilityIdentifier("paywall.buyButton")
            .revealed(.button, at: time)
            Group {
                if price == nil, store.productsFailed {
                    // Offline: the prices never came, and the buy button waits for them. One tap asks the App Store again.
                    Button {
                        Task { await store.loadProducts() }
                    } label: {
                        Text("Couldn't reach the App Store. Check your connection and try again.")
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoadingProducts)
                    .accessibilityIdentifier("paywall.retryPrices")
                } else {
                    Text(PaywallCopy.finePrint(for: selectedPlan, displayPrice: price))
                }
            }
            .cueFont(11.5)
            .foregroundStyle(Palette.ink2)
            .multilineTextAlignment(.center)
            .padding(.top, layout.fineGap)
            .revealed(.finePrint, at: time)
            HStack(spacing: 28) {
                Button("Restore") { Task { await restore() } }
                Button("Redeem code") { redeemsCode = true }.accessibilityIdentifier("paywall.redeemCode")
                if let terms = AppLinks.termsOfUse { Link("Terms", destination: terms) }
                if let privacy = AppLinks.privacyPolicy {
                    Link("Privacy", destination: privacy).accessibilityIdentifier("paywall.privacyLink")
                }
            }
            .cueFont(12.5)
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: Metrics.hitTarget)
            .padding(.bottom, 4)
            .revealed(.links, at: time)
            .offerCodeRedemption(options: [], isPresented: $redeemsCode) { _ in }
        }
        .padding(.horizontal, 16)
    }

    /// "$39.99 · $3.33/mo"
    private var yearlyDetail: String {
        let price = PaywallCopy.priceOnly(displayPrice: store.displayPrice(for: .annual))
        guard let monthly = store.monthlyEquivalentText(for: .annual) else { return price }
        return String(localized: "\(price) · \(monthly)/mo")
    }

    // MARK: - Actions

    /// The ring glides to the plan, a tick for each node the light reaches (or a plain one for Monthly's single node).
    private func pick(_ plan: ProPlan) {
        guard plan != selectedPlan else { return }
        withAnimation(.spring(duration: 0.42, bounce: 0.3)) { selectedPlan = plan }
        if plan == .annual, context != .ultra {
            HapticPatterns.playRingTicks(count: 11, every: 0.035)
        } else {
            Haptics.selection()
        }
    }

    /// The whole year lit for Yearly, this month for Monthly; Ultra AI's ring is the month's scripts, always lit.
    private func light(for plan: ProPlan) {
        guard context != .ultra else { return }
        ring = ProGalaxyArt.RingLight(lit: plan == .annual ? 12 : 1, was: ring.lit, since: .now)
    }

    private func purchase() async {
        guard await store.purchase(selectedPlan) else { return }
        complete()
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        let outcome = await store.restore()
        toast.show(outcome.message, kind: outcome.isRestored ? .done : .problem)
        if outcome.isRestored {
            dismiss()
            onPurchased()
        }
    }

    /// The galaxy's finish (the nodes run into the core, the flash, the gold wave), then the welcome; at once under Reduce Motion.
    private func complete() {
        guard finishedAt == nil else { return }
        finishedAt = .now
        guard !reduceMotion else {
            Haptics.success()
            finish()
            return
        }
        HapticPatterns.playProWelcome()
        Task {
            try? await Task.sleep(for: .seconds(ProGalaxyArt.finishLength))
            finish()
        }
    }

    private func finish() {
        dismiss()
        toast.show(PaywallCopy.welcome(for: context))
        onPurchased()
    }
}
