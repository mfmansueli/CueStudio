//
//  RemoteEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of Settings › Remote: connect another device to this teleprompter, or make this iPhone the remote of another one.
struct RemoteEntryRow: View {
    let entry: SettingsEntry

    @Environment(RemoteControlService.self) private var remote
    @Environment(PresentationService.self) private var presentation
    @Environment(ToastService.self) private var toast

    @State private var isEnteringCode = false
    @State private var typedCode = ""
    @State private var isScanning = false

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
            .alert("Enter the code", isPresented: $isEnteringCode) {
                TextField("ABC 234", text: $typedCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Connect") { join(typedCode) }
            } message: {
                Text("The six letters and numbers under the QR code on the teleprompter.")
            }
            .sheet(isPresented: $isScanning) {
                QRScannerSheet { payload in
                    isScanning = false
                    join(payload)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .connectDevice:
            connect
        case .enterCode:
            Button {
                typedCode = ""
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
                SettingsIconLabel(
                    systemImage: "iphone.radiowaves.left.and.right", tint: Palette.iconBlue, title: entry.title, titleColor: Palette.accText
                )
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

    private func join(_ text: String) {
        guard remote.join(code: text) else {
            toast.show(String(localized: "Wrong code · Try again"))
            return
        }
        presentation.openRemoteController()
    }
}
