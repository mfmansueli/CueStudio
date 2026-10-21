//
//  RemoteEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The Remote rows that Settings' search finds: connect another device to this teleprompter, or make this iPhone the remote of another
/// one (the page itself draws them its own way, `SettingsRemoteView`).
struct RemoteEntryRow: View {
    let entry: SettingsEntry

    @Environment(RemoteControlService.self) private var remote

    @State private var isEnteringCode = false
    @State private var isScanning = false

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
            .remoteJoinFlow(isEnteringCode: $isEnteringCode, isScanning: $isScanning)
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .connectDevice:
            connect
        case .enterCode:
            Button {
                isEnteringCode = true
            } label: {
                chevronLabel
            }
            .buttonStyle(.plain)
        case .scanCode:
            Button { isScanning = true } label: { chevronLabel }
                .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }

    private var chevronLabel: some View {
        HStack {
            Text(entry.title).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
        }
        .frame(minHeight: Metrics.listRowContent)
        .contentShape(Rectangle())
    }

    /// Off: the button. Waiting: the QR code and the letters. Connected: who, and Disconnect.
    @ViewBuilder
    private var connect: some View {
        switch (remote.role, remote.state) {
        case (nil, _):
            Button { remote.startHosting() } label: {
                SettingsIconLabel(icon: .remote, title: entry.title, titleColor: Palette.accText)
            }
            .buttonStyle(.plain)
        case (.teleprompter?, .connected(let deviceName)):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.successText)
                    Text(deviceName).foregroundStyle(Palette.ink)
                }
                Button("Disconnect", role: .destructive) { remote.disconnect() }
                    .accessibilityIdentifier("remote.disconnectButton")
            }
            .frame(minHeight: Metrics.listRowContent)
        default:
            RemotePairingPanel()
                .padding(.vertical, 6)
        }
    }
}
