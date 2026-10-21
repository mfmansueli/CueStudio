//
//  NotificationPermissionRow.swift
//  Cue Studio
//

import SwiftUI

/// The top of Settings › Notifications (owner's redesign, 22/10/2026: short and direct): whether iOS lets Cue speak, as a switch like the
/// page's others. A bell that sways now and then while off, as if about to ring; what is on or off, in a line. Never asked, switching it on
/// brings up iOS's question (once), and its yes turns everything on: the bell rings and takes a ✓ while the switches below light
/// (`NotificationsSettingsView`). Any other change opens Cue in iOS Settings, since an app can't allow or silence itself.
struct NotificationPermissionRow: View {
    enum Mood: Equatable {
        case notAsked, refused, quiet, allowed
    }

    let mood: Mood
    /// When the bell rang (iOS said yes): it swings hard and fades.
    let rangAt: Date?
    @Binding var isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                bell
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("notifications.permission.title")
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentTransition(.opacity)
            }
        }
        .tint(Palette.success)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .accessibilityIdentifier("notifications.permission")
    }

    // MARK: - The bell

    private var bell: some View {
        AmbientTimeline(interval: nil, paused: mood == .allowed && rangAt == nil) { ambient in
            Image(systemName: "bell")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Palette.accText)
                .rotationEffect(.degrees(swing(at: ambient)), anchor: UnitPoint(x: 0.5, y: 0.1))
                .frame(width: 28, height: 28)
        }
        .overlay(alignment: .bottomTrailing) {
            if mood == .allowed {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 14, height: 14)
                    .background(Palette.success, in: Circle())
                    .overlay(Circle().stroke(Palette.surface, lineWidth: 2))
                    .offset(x: 4, y: 3)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .accessibilityHidden(true)
    }

    /// Degrees: a hard ring fading over a second once allowed; while off, a small sway every few seconds, as if the bell were waiting.
    /// Still with Reduce Motion.
    private func swing(at ambient: AmbientTime) -> Double {
        guard !reduceMotion else { return 0 }
        if let rangAt {
            let since = ambient.date.timeIntervalSince(rangAt)
            guard since >= 0, since < 1.4 else { return 0 }
            return 22 * exp(-3.2 * since) * sin(2 * .pi * 3.1 * since)
        }
        guard mood == .notAsked || mood == .refused else { return 0 }
        let phase = ambient.seconds.truncatingRemainder(dividingBy: 4.8)
        guard phase < 1.2 else { return 0 }
        return 9 * exp(-3.4 * phase) * sin(2 * .pi * 2.4 * phase)
    }

    // MARK: - Words

    private var title: String {
        switch mood {
        case .notAsked: String(localized: "Notifications are off")
        case .refused: String(localized: "Notifications are off in iOS")
        case .quiet: String(localized: "Notifications arrive quietly")
        case .allowed: String(localized: "Notifications are on")
        }
    }

    private var detail: String {
        switch mood {
        case .notAsked: String(localized: "Cue can’t remind you yet.")
        case .refused: String(localized: "Allow Cue in iOS Settings.")
        case .quiet: String(localized: "Without a banner or a sound.")
        case .allowed: String(localized: "Cue only reaches out when it helps.")
        }
    }
}
