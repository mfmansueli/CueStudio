//
//  AppIconPicker.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize › App icon: the five icons side by side, as a collection to complete. The chosen one has the yellow ring and ✓
/// (`SelectionRing`, over the whole row, gliding above the other icons to the next on a firm spring); one not open yet is dimmed with a
/// lock and says when it opens ("10 · Pro"). Choosing asks iOS to change the icon; a locked one shakes its lock and says how many videos it
/// waits for; one that needs Pro opens the plans.
struct AppIconPicker: View {
    @Environment(AppIconService.self) private var appIcon
    @Environment(MilestoneService.self) private var milestones
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var tiles
    @State private var paywall: PaywallContext?
    @State private var shaking: AppIconChoice?
    @State private var shakes = 0

    private static let size: CGFloat = 58

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(AppIconChoice.allCases) { icon in
                tile(icon).frame(maxWidth: .infinity)
            }
        }
        .selectionRing(
            on: appIcon.current, in: tiles,
            shape: RoundedRectangle(cornerRadius: AppIconArt.radius(for: Self.size) + 4, style: .continuous), reduceMotion: reduceMotion
        )
        .animation(reduceMotion ? CueMotion.fade : .spring(duration: 0.4, bounce: 0.12), value: appIcon.current)
        .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.appIcon")
        // Five icons share one row: past the largest standard size their names no longer fit a fifth of it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func tile(_ icon: AppIconChoice) -> some View {
        let isUnlocked = milestones.isUnlocked(icon)
        let isCurrent = appIcon.current == icon
        return Button { choose(icon, isUnlocked: isUnlocked) } label: {
            VStack(spacing: 7) {
                AppIconArt(icon: icon, size: Self.size)
                    .opacity(isUnlocked ? 1 : 0.42)
                    .scaleEffect(isCurrent ? 1 : 0.94)
                    .frame(width: Self.size + 8, height: Self.size + 8)
                    .selectionRingAnchor(icon, in: tiles)
                    .overlay(alignment: .bottomTrailing) {
                        if !isUnlocked {
                            lockBadge
                                .keyframeAnimator(initialValue: 0.0, trigger: shaking == icon ? shakes : 0) { content, angle in
                                    content.rotationEffect(.degrees(angle), anchor: .top)
                                } keyframes: { _ in
                                    KeyframeTrack {
                                        SpringKeyframe(14, duration: 0.08)
                                        SpringKeyframe(-12, duration: 0.1)
                                        SpringKeyframe(8, duration: 0.1)
                                        SpringKeyframe(0, duration: 0.2)
                                    }
                                }
                        }
                    }
                Text(icon.title)
                    .cueFont(.caption)
                    .foregroundStyle(isCurrent ? Palette.ink : Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let note = note(icon, isUnlocked: isUnlocked) {
                    Text(verbatim: note)
                        .cueFont(.caption2)
                        .foregroundStyle(Palette.inkHint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(icon.title))
        .accessibilityValue(Text(isUnlocked ? "" : String(localized: "Unlocks at \(icon.milestone) videos shared")))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("settings.appIcon.\(icon.rawValue)")
    }

    /// "10 · Pro" under an icon that isn't open yet (and under Aurora, "1 video"); nothing under the open ones past that.
    private func note(_ icon: AppIconChoice, isUnlocked: Bool) -> String? {
        guard icon != .standard, !isUnlocked || icon.needsPro && !store.tier.isPro else { return nil }
        guard icon.needsPro else { return String(localized: "1 video") }
        return "\(icon.milestone) · " + String(localized: "Pro")
    }

    /// The lock on an icon not open yet (the chosen one's ✓ is the ring's, `SelectionRing`).
    private var lockBadge: some View {
        ZStack {
            Circle().fill(Palette.surface3)
            Image(systemName: "lock.fill")
                .font(.fixed(9, weight: .heavy))
                .foregroundStyle(Palette.ink)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().strokeBorder(Palette.bg, lineWidth: 1.5))
        .offset(x: 2, y: 2)
        .transition(.scale.combined(with: .opacity))
        .accessibilityHidden(true)
    }

    private func choose(_ icon: AppIconChoice, isUnlocked: Bool) {
        guard isUnlocked else {
            Haptics.rigid()
            shaking = icon
            shakes += 1
            toast.show(String(localized: "Unlocks at \(icon.milestone) videos shared"), kind: .problem)
            return
        }
        if icon.needsPro, !store.tier.isPro {
            paywall = .profile
            return
        }
        guard appIcon.current != icon else { return }
        Task {
            if await appIcon.choose(icon) { Haptics.selection() }
        }
    }
}
