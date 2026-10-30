//
//  ProfilePlanCard.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · the plan in one row. Free: "Free plan · 4 OF 5 EXPORTS LEFT", a thin bar and "Try Pro ›" (opens 11.4). Pro: "Cue Pro" with
/// the plan and its renewal, and "Manage ›". Every feature is free; only exporting has a limit, and, where Ultra AI is offered, its scripts: a
/// violet line says how many are left ("ULTRA AI · 4 OF 5 FREE LEFT").
struct ProfilePlanCard: View {
    let onUpgrade: () -> Void
    let onManage: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(UsageQuotaService.self) private var quota
    @Environment(UltraScriptService.self) private var ultra

    var body: some View {
        Button(action: store.tier.isPro ? onManage : onUpgrade) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(store.tier.isPro ? "Cue Pro" : "Free plan").cueFont(14).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Text(detail)
                            .monoFont(size: 11, weight: .semibold)
                            .foregroundStyle(detailTint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if !store.tier.isPro {
                        UsageMeter(fraction: Double(left) / Double(max(1, UsagePolicy.freeExports)), color: left > 0 ? Palette.ink2 : Palette.warnText)
                    }
                    if ultra.isAvailable, let allowance = ultra.allowance?.allowance {
                        Text(verbatim: UltraAllowanceLabels.plan(allowance))
                            .monoFont(size: 11, weight: .semibold)
                            .foregroundStyle(allowance.left > 0 ? Palette.aiText : Palette.warnText)
                            // A script written while the Profile is open: the number rolls down.
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.smooth, value: allowance.left)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityIdentifier("profile.ultraAllowance")
                    }
                }
                Text(store.tier.isPro ? "Manage ›" : "Try Pro ›")
                    .cueFont(14, weight: .semibold)
                    .foregroundStyle(Palette.accText)
                    .fixedSize()
            }
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 14))
            .padding(.vertical, ultra.isAvailable ? 10 : 0)
            .frame(minHeight: 60)
            .profileBlock()
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(store.tier.isPro ? "profile.manageButton" : "profile.upgradeButton")
    }

    private var left: Int { quota.exportsLeft(for: .free) ?? 0 }

    private var detail: String {
        if store.tier.isPro {
            guard let plan = store.activePlan else { return String(localized: "Active") }
            return plan.label.uppercased()
        }
        return FreeExportLabels.plan(left: left).text
    }

    /// The count turns yellow on the last free export and orange once they are gone.
    private var detailTint: Color {
        guard !store.tier.isPro else { return Palette.ink2 }
        switch FreeExportLabels.plan(left: left).tone {
        case .quiet: return Palette.ink2
        case .last: return Palette.accText
        case .exhausted: return Palette.warnText
        }
    }
}
