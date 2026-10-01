//
//  RemotePairingPanel.swift
//  Cue Studio
//

import SwiftUI

/// The teleprompter's side of pairing: "Connect a Device", then a QR code (and the same code in
/// letters) until the other iPhone or iPad joins, then "Remote Connected ✓". Used in Settings ›
/// Creator Setup › Remote Control and over the prompter.
struct RemotePairingPanel: View {
    @Environment(RemoteControlService.self) private var remote
    @Environment(PresentationService.self) private var presentation

    var body: some View {
        Group {
            switch (remote.role, remote.state) {
            case (.remote?, _):
                remoteHere
            case (.teleprompter?, .connected(let deviceName)):
                connected(deviceName)
            case (.teleprompter?, .failed(let message)):
                failed(message)
            case (.teleprompter?, _):
                pairing
            case (nil, _):
                start
            }
        }
        .animation(.smooth(duration: 0.3), value: remote.state)
    }

    // MARK: - States

    private var start: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Play, pause, change speed and move through the script from a second iPhone or iPad. Both need Cue, and Wi-Fi on.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                remote.startHosting()
            } label: {
                Label("Connect a Device", systemImage: "qrcode")
            }
            .buttonStyle(.cuePrimary())
            .accessibilityIdentifier("remote.connectButton")
        }
    }

    private var pairing: some View {
        VStack(spacing: 14) {
            if let url = remote.pairingURL, let code = remote.code {
                QRCodeView(text: url.absoluteString)
                    .frame(width: 200, height: 200)
                    .accessibilityLabel(Text("Pairing QR code"))
                    .accessibilityIdentifier("remote.qrCode")
                Text(RemotePairing.display(code))
                    .font(.title2.weight(.bold).monospaced())
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel(Text("Code \(code.map(String.init).joined(separator: " "))"))
                    .accessibilityIdentifier("remote.code")
            }
            Text("On the other iPhone or iPad, scan this with the Camera — or open Cue › Settings › Creator Setup › Remote Control and enter the code.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView().tint(Palette.ink2)
                Text(remote.state.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("remote.status")
            Button("Cancel") { remote.disconnect() }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("remote.cancelButton")
        }
        .frame(maxWidth: .infinity)
    }

    private func connected(_ deviceName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Palette.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Remote Connected").font(.headline)
                Text(deviceName)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 8)
            Button("Disconnect") { remote.disconnect() }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("remote.disconnectButton")
        }
        .padding(14)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("remote.connected")
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Palette.warn)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { remote.startHosting() }
                .buttonStyle(.cueSecondary(.compact, expands: false))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// This device is someone else's remote right now.
    private var remoteHere: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This device is a remote right now.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
            HStack(spacing: 8) {
                Button("Open remote") { presentation.openRemoteController() }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                Button("Stop") { remote.disconnect() }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    RemotePairingPanel()
        .padding()
        .background(Palette.surface)
        .previewEnvironment()
}
#endif
