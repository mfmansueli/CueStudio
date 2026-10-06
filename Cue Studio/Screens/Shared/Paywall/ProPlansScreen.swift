//
//  ProPlansScreen.swift
//  Cue Studio
//

import SwiftUI

/// Cue Pro, as the prototype draws it (11.4): the eyebrow, the title and the line under it, what Pro offers, the two plans side by side, the yellow
/// button, the small print and Restore · Terms · Privacy. The same screen for both: the regular Pro ("CUE PRO", after the opening) and the calm one
/// ("YOUR VIDEO IS READY", from the free exports running out). The system's `SubscriptionStoreView` can't be drawn like this, so the plans, the button
/// and the small print are Cue's own, over StoreKit 2 (`StoreManager`).
struct ProPlansScreen: View {
    let context: PaywallContext
    /// The second of the opening (`ProOpeningScript`); the end of it shows everything in place.
    var time = ProOpeningScript.settled
    /// How far down the screen the safe area starts: the art is placed from the top of the screen, not of the safe area.
    var topInset: CGFloat = 0
    let onPurchased: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(AIStatus.self) private var aiStatus
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: ProPlan = .annual
    @State private var trialDays: [ProPlan: Int] = [:]
    @State private var showsPrivacy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ProMarketing(context: context, aiIsAvailable: aiStatus.isAvailable, time: time)
                    .padding(.top, 96)
                    .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            // The planet that is you, above the title: the board's art starts 18 pt from the top of the screen (its centre is 100 pt down).
            .overlay(alignment: .top) {
                ProPlanetArt(ignition: ProOpeningScript.planet.pose(at: time)).offset(y: 18 - topInset)
            }
            // The footer (the plans, the button and the small print) stops growing at a large size: at the biggest it left no room above it.
            footer.dynamicTypeSize(...DynamicTypeSize.xxxLarge).revealed(7, at: time)
        }
        .task {
            await store.loadProducts()
            for plan in ProPlan.allCases {
                if let days = await store.freeTrialDays(for: plan) { trialDays[plan] = days }
            }
        }
        .onChange(of: store.tier.isPro) { _, isPro in
            if isPro, context == .profile { complete(startedTrial: true) }
        }
        .alert("Purchase", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
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
                        isSelected: selectedPlan == plan
                    ) { selectedPlan = plan }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            Button {
                Task { await purchase() }
            } label: {
                if store.purchasingPlan != nil {
                    ProgressView().tint(Palette.accInk)
                } else {
                    Text(PaywallCopy.callToAction(for: selectedPlan, displayPrice: price, trialDays: trialDays[selectedPlan], context: context))
                        .fontWeight(.bold)
                }
            }
            .buttonStyle(.cuePrimary(.large))
            .shadow(color: Palette.acc.opacity(0.3), radius: 22)
            .shineSweep(interval: 3.6)
            .disabled(price == nil || store.purchasingPlan != nil)
            .padding(.horizontal, 16)
            .accessibilityIdentifier("paywall.buyButton")
            Text(PaywallCopy.finePrint(for: selectedPlan, displayPrice: price, trialDays: trialDays[selectedPlan]))
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.inkHint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            HStack(spacing: 28) {
                Button("Restore") { Task { await restore() } }
                if let terms = AppLinks.termsOfUse { Link("Terms", destination: terms) }
                // Until the policy has a URL, Privacy opens the same summary as the Profile.
                if let privacy = AppLinks.privacyPolicy {
                    Link("Privacy", destination: privacy)
                } else {
                    Button("Privacy") { showsPrivacy = true }.accessibilityIdentifier("paywall.privacyButton")
                }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: Metrics.hitTarget)
            .padding(.bottom, 4)
        }
    }

    /// "$39.99 · $3.33/mo"
    private var yearlyDetail: String {
        let price = PaywallCopy.priceOnly(displayPrice: store.displayPrice(for: .annual))
        guard let monthly = store.monthlyEquivalentText(for: .annual) else { return price }
        return String(localized: "\(price) · \(monthly)/mo")
    }

    // MARK: - Actions

    private func purchase() async {
        let startsTrial = trialDays[selectedPlan] != nil
        guard await store.purchase(selectedPlan) else { return }
        complete(startedTrial: startsTrial)
    }

    private func restore() async {
        if await store.restore() {
            dismiss()
            toast.show(String(localized: "Purchases restored"))
            onPurchased()
        } else {
            toast.show(String(localized: "No purchases to restore"))
        }
    }

    private func complete(startedTrial: Bool) {
        dismiss()
        toast.show(PaywallCopy.welcome(for: context, startedTrial: startedTrial))
        onPurchased()
    }
}
