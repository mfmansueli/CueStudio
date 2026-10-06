//
//  AppIconView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize › App icon: Cue's own and the ones videos shared in the creator's universe open. A locked icon says what opens it
/// ("25 videos", "50 videos · Pro"); the ones Pro unlocks open the plans.
struct AppIconView: View {
    @Environment(AppIconService.self) private var appIcon
    @Environment(MilestoneService.self) private var milestones
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast

    @State private var paywall: PaywallContext?

    var body: some View {
        List {
            Section {
                ForEach(AppIconChoice.allCases) { icon in
                    row(icon)
                        .cardRowBackground()
                }
            } footer: {
                Text("Unlock with milestones. Some come with Pro.")
            }
        }
        .cueGroupedList()
        .navigationTitle("App icon")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
        .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
    }

    private func row(_ icon: AppIconChoice) -> some View {
        let isUnlocked = milestones.isUnlocked(icon)
        let isCurrent = appIcon.current == icon
        return Button { choose(icon, isUnlocked: isUnlocked) } label: {
            HStack(spacing: 12) {
                Text(icon.title).foregroundStyle(isUnlocked ? Palette.ink : Palette.inkHint)
                Spacer(minLength: 8)
                if isCurrent {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accText)
                } else if !isUnlocked {
                    Text(requirement(icon)).foregroundStyle(Palette.inkHint)
                }
            }
            .frame(minHeight: Metrics.listRowContent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("settings.appIcon.\(icon.rawValue)")
    }

    /// "25 videos", "50 videos · Pro"
    private func requirement(_ icon: AppIconChoice) -> String {
        let videos = icon.milestone == 1 ? String(localized: "1 video") : String(localized: "\(icon.milestone) videos")
        return icon.needsPro ? videos + " · " + String(localized: "Pro") : videos
    }

    private func choose(_ icon: AppIconChoice, isUnlocked: Bool) {
        guard isUnlocked else {
            toast.show(String(localized: "Unlocks at \(icon.milestone) videos shared"))
            return
        }
        if icon.needsPro, !store.tier.isPro {
            paywall = .profile
            return
        }
        Task {
            if await appIcon.choose(icon) { Haptics.selection() }
        }
    }
}
