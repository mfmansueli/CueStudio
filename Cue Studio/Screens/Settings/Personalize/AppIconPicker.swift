//
//  AppIconPicker.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize › App icon: the five icons side by side, as a collection to complete. The chosen one has a yellow ring (it glides
/// from icon to icon on a spring) and a ✓; one not open yet is dimmed with a lock and says when it opens ("10 · Pro"). Choosing asks iOS
/// to change the icon; a locked one shakes its lock and says how many videos it waits for; one that needs Pro opens the plans.
struct AppIconPicker: View {
    @Environment(AppIconService.self) private var appIcon
    @Environment(MilestoneService.self) private var milestones
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var ring
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
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.42, dampingFraction: 0.72), value: appIcon.current)
        .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.appIcon")
    }

    private func tile(_ icon: AppIconChoice) -> some View {
        let isUnlocked = milestones.isUnlocked(icon)
        let isCurrent = appIcon.current == icon
        return Button { choose(icon, isUnlocked: isUnlocked) } label: {
            VStack(spacing: 7) {
                ZStack {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: AppIconArt.radius(for: Self.size) + 4, style: .continuous)
                            .strokeBorder(Palette.acc, lineWidth: 2)
                            .frame(width: Self.size + 8, height: Self.size + 8)
                            .matchedGeometryEffect(id: "ring", in: ring)
                    }
                    AppIconArt(icon: icon, size: Self.size)
                        .opacity(isUnlocked ? 1 : 0.42)
                        .scaleEffect(isCurrent ? 1 : 0.94)
                }
                .frame(width: Self.size + 8, height: Self.size + 8)
                .overlay(alignment: .topTrailing) { if isCurrent { badge(check: true) } }
                .overlay(alignment: .bottomTrailing) {
                    if !isUnlocked {
                        badge(check: false)
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
                    .font(.caption)
                    .foregroundStyle(isCurrent ? Palette.ink : Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let note = note(icon, isUnlocked: isUnlocked) {
                    Text(verbatim: note)
                        .font(.caption2)
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

    private func badge(check: Bool) -> some View {
        ZStack {
            Circle().fill(check ? Palette.acc : Palette.surface3)
            Image(systemName: check ? "checkmark" : "lock.fill")
                .font(.system(size: check ? 10 : 9, weight: .heavy))
                .foregroundStyle(check ? Palette.accInk : Palette.ink)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().strokeBorder(Palette.bg, lineWidth: 1.5))
        .offset(x: 2, y: check ? -2 : 2)
        .transition(.scale.combined(with: .opacity))
        .accessibilityHidden(true)
    }

    private func choose(_ icon: AppIconChoice, isUnlocked: Bool) {
        guard isUnlocked else {
            Haptics.rigid()
            shaking = icon
            shakes += 1
            toast.show(String(localized: "Unlocks at \(icon.milestone) videos shared"))
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
