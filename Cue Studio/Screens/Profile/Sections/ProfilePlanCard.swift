//
//  ProfilePlanCard.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · the plan in one card. Free: "Free plan" and "Try Pro ›" (opens 11.4) over one bar for each limit (the owner, 30/10/2026): the exports
/// ("2 OF 3 EXPORTS LEFT", grey) and, where Ultra AI is offered, its scripts ("ULTRA AI · 2 OF 3 FREE LEFT", violet). Pro: "Cue Pro" with
/// the plan and "Manage ›", and the Ultra AI bar. Every feature is free; only exporting and Ultra AI's scripts have a limit.
struct ProfilePlanCard: View {
    let onUpgrade: () -> Void
    let onManage: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(UsageQuotaService.self) private var quota
    @Environment(UltraScriptService.self) private var ultra

    var body: some View {
        Button(action: store.tier.isPro ? onManage : onUpgrade) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(store.tier.isPro ? "Cue Pro" : "Free plan").cueFont(14).foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    if store.tier.isPro {
                        Text(detail).monoFont(size: 11, weight: .semibold).foregroundStyle(Palette.ink2).lineLimit(1)
                    }
                    Text(store.tier.isPro ? "Manage ›" : "Try Pro ›")
                        .cueFont(14, weight: .semibold)
                        .foregroundStyle(Palette.accText)
                        .fixedSize()
                }
                if !store.tier.isPro {
                    meter(
                        detail, tint: detailTint,
                        fraction: Double(left) / Double(max(1, UsagePolicy.freeExports)), color: left > 0 ? Palette.ink2 : Palette.warnText
                    )
                }
                if ultra.isAvailable, let allowance = ultra.allowance?.allowance {
                    let tint = allowance.left > 0 ? Palette.aiText : Palette.warnText
                    meter(UltraAllowanceLabels.plan(allowance), tint: tint, fraction: ultraFraction(allowance), color: tint)
                        // A script written while the Profile is open: the number rolls down.
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.smooth, value: allowance.left)
                        .accessibilityIdentifier("profile.ultraAllowance")
                }
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
            .frame(minHeight: 60)
            .profileBlock()
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(store.tier.isPro ? "profile.manageButton" : "profile.upgradeButton")
    }

    /// One limit: what is left, in mono, over its bar.
    private func meter(_ label: String, tint: Color, fraction: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: label)
                .monoFont(size: 11, weight: .semibold)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            UsageMeter(fraction: fraction, color: color)
        }
    }

    private var left: Int { quota.exportsLeft(for: .free) ?? 0 }

    /// What is left of the Ultra AI scripts: of the free ones, or, on Pro, of the month's with any free ones still unused.
    private func ultraFraction(_ allowance: UltraAllowance) -> Double {
        let total = allowance.membership == .paid ? allowance.freeLeft + UsagePolicy.proUltraScriptsPerMonth : UsagePolicy.freeUltraScripts
        return Double(allowance.left) / Double(max(1, total))
    }

    private var detail: String {
        if store.tier.isPro {
            guard let plan = store.activePlan else { return String(localized: "Active") }
            return plan.label.uppercased()
        }
        return FreeExportLabels.plan(left: left).text
    }

    /// The count turns yellow on the last free export and orange once they are gone.
    private var detailTint: Color {
        switch FreeExportLabels.plan(left: left).tone {
        case .quiet: Palette.ink2
        case .last: Palette.accText
        case .exhausted: Palette.warnText
        }
    }
}
