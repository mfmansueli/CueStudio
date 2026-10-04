//
//  PaywallView.swift
//  Cue Studio
//

import SwiftUI

/// Cue Pro: two subscriptions, each starting with a 7-day free trial. Opens only when the free
/// exports run out or from Profile (never while recording). Full screen, dismissible, always offers
/// Restore.
struct PaywallView: View {
    let context: PaywallContext
    var onPurchased: (() -> Void)?

    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(UsageQuotaService.self) private var quota
    @Environment(AIStatus.self) private var aiStatus
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: ProPlan = .annual
    @State private var trialDays: [ProPlan: Int] = [:]
    @State private var showsPrivacy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 7) {
                        Circle().fill(Palette.acc).frame(width: 7, height: 7)
                        Text("Cue Pro")
                            .font(CueStudioFont.hud)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(Palette.accText)
                    }
                    Text(PaywallCopy.title(for: context))
                        .font(.system(size: 32, weight: .bold))
                        .padding(.top, 8)
                    Text(PaywallCopy.subtitle(for: context))
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.65))
                        .padding(.top, 10)
                    if context == .export {
                        PaywallExportsMeter(used: UsagePolicy.freeExports - (quota.exportsLeft(for: .free) ?? 0), limit: UsagePolicy.freeExports)
                            .padding(.top, 18)
                    }
                    PaywallBenefitsCard(aiIsAvailable: aiStatus.isAvailable)
                        .padding(.top, 20)
                    VStack(spacing: 10) {
                        ForEach(ProPlan.allCases) { plan in planRow(plan) }
                    }
                    .padding(.top, 22)
                }
                .padding(EdgeInsets(top: 100, leading: 20, bottom: 16, trailing: 20))
            }
            .scrollIndicators(.hidden)
            // The footer (the button and the small print) stops growing at a large size: at the biggest it left no room for the plans above it.
            footer.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .foregroundStyle(Palette.ink)
        .background {
            ZStack(alignment: .top) {
                NightAuroraBackground(base: Palette.bg, yellowTouch: true)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 560)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .background(Palette.bg)
            .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.cueIcon(.glass, diameter: 36))
                .padding(.trailing, Metrics.gutter)
                .padding(.top, 8)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("paywall.closeButton")
        }
        .task {
            await store.loadProducts()
            for plan in ProPlan.allCases {
                if let days = await store.freeTrialDays(for: plan) { trialDays[plan] = days }
            }
        }
        .alert("Purchase", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private func planRow(_ plan: ProPlan) -> some View {
        let isSelected = selectedPlan == plan
        let badge = plan == .annual ? PaywallCopy.savingsBadge(percent: store.annualSavingsPercent) : nil
        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .strokeBorder(isSelected ? Palette.acc : Palette.ink3, lineWidth: isSelected ? 7 : 2)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.label).font(.body.weight(.semibold))
                    Text(PaywallCopy.detail(for: plan, monthlyEquivalent: store.monthlyEquivalentText(for: plan), trialDays: trialDays[plan]))
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 8)
                Text(PaywallCopy.price(for: plan, displayPrice: store.displayPrice(for: plan)))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Palette.accWashFaint : Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Palette.acc : Palette.separator, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .heavy))
                        .kerning(0.4)
                        .foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Palette.acc, in: Capsule())
                        .offset(x: -14, y: -10)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(plan.rawValue)")
    }

    private var footer: some View {
        let price = store.displayPrice(for: selectedPlan)
        return VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                if store.purchasingPlan != nil {
                    ProgressView().tint(Palette.accInk)
                } else {
                    Text(PaywallCopy.callToAction(for: selectedPlan, displayPrice: price, trialDays: trialDays[selectedPlan]))
                        .fontWeight(.bold)
                }
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(price == nil || store.purchasingPlan != nil)
            .accessibilityIdentifier("paywall.buyButton")
            Text(PaywallCopy.finePrint(for: selectedPlan, displayPrice: price, trialDays: trialDays[selectedPlan]))
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore") { Task { await restore() } }
                if let terms = AppLinks.termsOfUse { Link("Terms", destination: terms) }
                // Until the policy has a URL, Privacy opens the same summary as the Profile.
                if let privacy = AppLinks.privacyPolicy {
                    Link("Privacy", destination: privacy)
                } else {
                    Button("Privacy") { showsPrivacy = true }
                        .accessibilityIdentifier("paywall.privacyButton")
                }
            }
            .font(.caption)
            .foregroundStyle(Palette.ink2)
            .frame(minHeight: Metrics.hitTarget)
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .background { Rectangle().fill(Palette.glassBase.opacity(0.94)).ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { Rectangle().fill(Palette.glassBorder).frame(height: 0.5) }
        .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
    }

    // MARK: - Actions

    private func purchase() async {
        let startsTrial = trialDays[selectedPlan] != nil
        guard await store.purchase(selectedPlan) else { return }
        dismiss()
        toast.show(PaywallCopy.welcome(for: context, startedTrial: startsTrial))
        onPurchased?()
    }

    private func restore() async {
        if await store.restore() {
            dismiss()
            toast.show(String(localized: "Purchases restored"))
            onPurchased?()
        } else {
            toast.show(String(localized: "No purchases to restore"))
        }
    }
}

#if DEBUG
#Preview {
    PaywallView(context: .export)
        .previewEnvironment()
}
#endif
