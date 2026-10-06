//
//  RemoteStatusHero.swift
//  Cue Studio
//

import SwiftUI

/// The top of Settings › Remote: a ring that is grey with no remote, yellow while pairing and green
/// once connected, with what it means under it.
struct RemoteStatusHero: View {
    let state: RemoteConnectionState
    let deviceName: String?

    private var color: Color {
        switch state {
        case .connected: Palette.success
        case .off: Palette.ink3
        default: Palette.acc
        }
    }

    private var title: String {
        switch state {
        case .connected: String(localized: "Remote connected")
        case .off, .failed: String(localized: "No remote connected")
        case .waiting, .searching: state.label
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 96, height: 96)
                Circle().strokeBorder(color, lineWidth: 2).frame(width: 58, height: 58)
                Image(systemName: state.isConnected ? "checkmark" : "iphone.radiowaves.left.and.right")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Text(deviceName ?? String(localized: "Play, pause and change speed from another iPhone, iPad or Apple Watch."))
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.glassBorder.opacity(0.6), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("remote.statusHero")
    }
}
