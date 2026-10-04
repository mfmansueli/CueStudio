//
//  ProfilePlanCard.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · the plan in one row. Free: "Free plan · 4 OF 5 EXPORTS LEFT", a thin bar and "Try Pro ›" (opens 11.4). Pro: "Cue Pro" with
/// the plan and its renewal, and "Manage ›". Every feature is free; only exporting has a limit.
struct ProfilePlanCard: View {
    let onUpgrade: () -> Void
    let onManage: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(UsageQuotaService.self) private var quota

    var body: some View {
        Button(action: store.tier.isPro ? onManage : onUpgrade) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(store.tier.isPro ? "Cue Pro" : "Free plan").font(.system(size: 14)).foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Text(detail)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if !store.tier.isPro {
                        UsageMeter(fraction: Double(left) / Double(max(1, UsagePolicy.freeExports)), color: left > 0 ? Palette.ink2 : Palette.warnText)
                    }
                }
                Text(store.tier.isPro ? "Manage ›" : "Try Pro ›")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .fixedSize()
            }
            .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 14))
            .frame(minHeight: 60)
            .profileBlock()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(store.tier.isPro ? "profile.manageButton" : "profile.upgradeButton")
    }

    private var left: Int { quota.exportsLeft(for: .free) ?? 0 }

    private var detail: String {
        if store.tier.isPro {
            guard let plan = store.activePlan else { return String(localized: "Active") }
            return plan.label.uppercased()
        }
        return String(localized: "\(left) OF \(UsagePolicy.freeExports) EXPORTS LEFT")
    }
}
