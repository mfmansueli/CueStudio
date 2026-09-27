//
//  PaywallView.swift
//  Cue Studio
//

import SwiftUI

/// Cue Pro upgrade. Full screen, dismissible, always offers Restore.
struct PaywallView: View {
    let context: PaywallContext
    /// Export context only: continue with a watermarked export instead of upgrading.
    var onWatermarkInstead: (() -> Void)?
    var onPurchased: (() -> Void)?

    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: ProPlan = .annual
    @State private var trialDays: [ProPlan: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if context == .export { exportComparison }
                    Text("Cue Pro")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(Palette.acc)
                    Text(PaywallCopy.title(for: context))
                        .font(.largeTitle.bold())
                        .padding(.top, 8)
                    Text(PaywallCopy.subtitle(for: context))
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.65))
                        .padding(.top, 10)
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(PaywallCopy.features, id: \.self) { feature in
                            Label {
                                Text(feature)
                            } icon: {
                                Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Palette.acc)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.top, 20)
                    VStack(spacing: 10) {
                        ForEach(ProPlan.allCases) { plan in planRow(plan) }
                    }
                    .padding(.top, 22)
                }
                .padding(EdgeInsets(top: 100, leading: 20, bottom: 16, trailing: 20))
            }
            .scrollIndicators(.hidden)
            footer
        }
        .foregroundStyle(Palette.ink)
        .background {
            ZStack(alignment: .top) {
                Color.black
                RadialGradient(colors: [Palette.acc.opacity(0.24), .clear], center: .top, startRadius: 0, endRadius: 360)
                    .frame(height: 420)
            }
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
            for plan in ProPlan.allCases where plan.isSubscription {
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

    private var exportComparison: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x7A6250), Color(hex: 0x2A211C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 78, height: 138)
                .overlay(alignment: .bottomTrailing) {
                    Text("Made with Cue")
                        .font(.system(size: 7.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
                        .padding(6)
                }
                .opacity(0.7)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x7A6250), Color(hex: 0x2A211C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 78, height: 138)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.acc, lineWidth: 2))
                .overlay(alignment: .topLeading) {
                    Text("PRO")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(Palette.acc, in: Capsule())
                        .padding(6)
                }
        }
        .padding(.bottom, 18)
        .accessibilityHidden(true)
    }

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
            .background(isSelected ? Palette.acc.opacity(0.07) : Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
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
                .foregroundStyle(Palette.ink.opacity(0.5))
                .multilineTextAlignment(.center)
            if let onWatermarkInstead {
                Button("Save with watermark instead") {
                    dismiss()
                    onWatermarkInstead()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("paywall.watermarkButton")
            }
            HStack(spacing: 18) {
                Button("Restore") { Task { await restore() } }
                if let terms = AppLinks.termsOfUse { Link("Terms", destination: terms) }
                if let privacy = AppLinks.privacyPolicy { Link("Privacy", destination: privacy) }
            }
            .font(.caption)
            .foregroundStyle(Palette.ink.opacity(0.5))
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .background(Color.black)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
    }

    // MARK: - Actions

    private func purchase() async {
        guard await store.purchase(selectedPlan) else { return }
        dismiss()
        let message = switch context {
        case .export: String(localized: "Welcome to Pro — exporting without watermark")
        case .ai: String(localized: "Welcome to Pro — AI unlocked")
        case .profile: String(localized: "Welcome to Cue Pro")
        }
        toast.show(message)
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
    PaywallView(context: .export, onWatermarkInstead: {})
        .previewEnvironment()
}
#endif
