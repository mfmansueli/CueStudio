//
//  RemoteSetupSection.swift
//  Cue Studio
//

import SwiftUI

/// Creator Setup › Remote Control: pair a device, and see which one is connected and how.
struct RemoteSetupSection: View {
    @Environment(RemoteControlService.self) private var remote

    var body: some View {
        GroupedCard {
            NavigationLink {
                RemoteControlView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(Palette.acc)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect a Device").foregroundStyle(Palette.ink)
                        Text("Control your teleprompter from another iPhone or iPad.")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink3)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("creatorSetup.remoteButton")
            valueRow(String(localized: "Connected device"), value: remote.state.deviceName ?? String(localized: "None"))
            valueRow(String(localized: "Remote status"), value: statusText, color: remote.isConnected ? Palette.success : Palette.ink2)
                .accessibilityIdentifier("creatorSetup.remoteStatus")
        }
    }

    /// "Connected ✓", "Waiting for your other device…", "Off".
    private var statusText: String {
        switch remote.state {
        case .connected: String(localized: "Connected ✓")
        case .off: String(localized: "Off")
        default: remote.state.label
        }
    }

    private func valueRow(_ title: String, value: String, color: Color = Palette.ink2) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }
}
