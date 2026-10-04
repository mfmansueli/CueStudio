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
                Circle().strokeBorder(color, lineWidth: 3).frame(width: 72, height: 72)
                Image(systemName: state.isConnected ? "checkmark" : "iphone.radiowaves.left.and.right")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Text(deviceName ?? String(localized: "Control your teleprompter from another iPhone or iPad."))
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .nightAurora(in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous), yellowTouch: state.isConnected)
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("remote.statusHero")
    }
}
