//
//  PlanSection.swift
//  Cue Studio
//

import SwiftUI

/// Free-plan usage with an upgrade button, or the active Pro plan.
struct PlanSection: View {
    let trialDays: Int?
    let onUpgrade: () -> Void
    let onManage: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(UsageQuotaService.self) private var quota

    var body: some View {
        if store.tier.isPro { proCard } else { freeCard }
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Free plan").font(.headline)
                Spacer()
                Text("Teleprompter always free")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            usage(
                title: String(localized: "Clean exports"),
                left: quota.cleanExportsLeft(for: .free) ?? 0,
                limit: UsagePolicy.freeCleanExports
            )
            usage(
                title: String(localized: "AI scripts this month"),
                left: quota.aiScriptsLeft(for: .free) ?? 0,
                limit: UsagePolicy.freeAIScriptsPerMonth
            )
            Button(action: onUpgrade) {
                Label(trialDays.map { String(localized: "Try Pro free for \($0) days") } ?? String(localized: "Upgrade to Cue Pro"), systemImage: "sparkles")
            }
            .buttonStyle(.cuePrimary())
            .accessibilityIdentifier("profile.upgradeButton")
        }
        .padding(.vertical, 6)
    }

    private func usage(title: String, left: Int, limit: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(left) of \(limit) left")
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink2)
            }
            .font(.subheadline)
            UsageMeter(fraction: Double(left) / Double(max(1, limit)), color: left > 0 ? Palette.acc : Palette.warn)
        }
        .accessibilityElement(children: .combine)
    }

    private var proCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Cue Pro").font(.headline)
                Text(planLine)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink.opacity(0.7))
                Text(store.tier == .lifetime
                     ? String(localized: "Clean exports forever · \(UsagePolicy.lifetimeAIScriptsPerMonth) AI scripts a month")
                     : String(localized: "Unlimited clean exports & AI"))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink.opacity(0.7))
            }
            Spacer()
            if store.tier == .subscriber {
                Button("Manage", action: onManage)
                    .buttonStyle(.cueSecondary(.compact, expands: false))
            }
        }
        .padding(.vertical, 6)
    }

    private var planLine: String {
        guard let plan = store.activePlan else { return String(localized: "Active") }
        if let renewal = store.renewalDate {
            return String(localized: "\(plan.label) · renews \(renewal.formatted(date: .abbreviated, time: .omitted))")
        }
        return plan.label
    }
}
