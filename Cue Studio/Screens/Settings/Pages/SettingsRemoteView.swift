//
//  SettingsRemoteView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Remote (owner's redesign, 21/10/2026): the scene of the two devices on top (`RemoteHero`), what to do under it for the
/// stage it is in, then the ways to make this iPhone the remote of another one, what a remote can do, and what comes next.
/// - No remote: "No remote yet", the big yellow Connect a device (a press and a glint, `HapticPatterns.remoteSend`), what both need.
/// - Waiting: the code a character to a tile, "Waiting for your other device…", the steps on the other device, Cancel.
/// - Connected: CONNECTED, the device's name, what to try on it, and Disconnect (`HapticPatterns.remoteDisconnect`); the capabilities
///   light green.
/// - This iPhone is a remote: looking for the teleprompter or connected, with Open remote and Stop.
/// What changes between stages leaves quickly and the new arrives rising a little, after the scene has started to move.
struct SettingsRemoteView: View {
    @Environment(RemoteControlService.self) private var remote
    @Environment(PresentationService.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the middle of the page shows, one of a few layouts.
    private enum Moment: Hashable {
        case idle
        case failed(String)
        case pairing
        case linked(String)
        case remote
    }

    private var stage: RemoteStage { RemoteStage(role: remote.role, state: remote.state) }

    private var moment: Moment {
        switch (remote.role, remote.state) {
        case (.remote?, _): .remote
        case (_, .failed(let message)): .failed(message)
        case (.teleprompter?, .connected(let name)): .linked(name)
        case (.teleprompter?, _): .pairing
        case (nil, _): .idle
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RemoteHero(stage: stage, pairingText: remote.pairingURL?.absoluteString)
                    .padding(.top, 4)
                momentContent
                    .id(moment)
                    .transition(transition)
                if remote.role == nil {
                    RemoteJoinCards().padding(.top, 32)
                }
                if moment != .pairing, moment != .remote {
                    RemoteCapabilities(isLive: stage == .linked).padding(.top, 32)
                }
                comingNext.padding(.top, 32)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 32)
            .animation(reduceMotion ? CueMotion.fade : CueMotion.card, value: moment)
        }
        .scrollIndicators(.hidden)
        .skyBackground()
        .navigationTitle("Remote")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.remotePage")
    }

    /// The old leaves at once; the new rises in a beat later, once the scene has started to move.
    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 14)).animation(CueMotion.light(duration: 0.55).delay(0.18)),
            removal: .opacity.animation(.easeIn(duration: 0.16))
        )
    }

    @ViewBuilder
    private var momentContent: some View {
        switch moment {
        case .idle:
            VStack(spacing: 18) {
                headline(title: String(localized: "No remote yet"), detail: String(localized: "Play, pause and change speed from a second iPhone or iPad."))
                Button {
                    HapticPatterns.playRemoteSend()
                    remote.startHosting()
                } label: {
                    Label("Connect a device", systemImage: "qrcode")
                }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("remote.connectButton")
                Text("Both devices need Cue and Wi-Fi or Bluetooth on.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
        case .failed(let message):
            VStack(spacing: 18) {
                headline(title: String(localized: "Couldn’t connect"), detail: message)
                Button("Try again") {
                    HapticPatterns.playRemoteSend()
                    remote.startHosting()
                }
                .buttonStyle(.cuePrimary(.large))
            }
        case .pairing:
            VStack(spacing: 16) {
                if let code = remote.code { RemoteCodeChips(code: code) }
                RemoteWaitingStatus(text: remote.state.label)
                RemoteWaitingSteps().padding(.top, 14)
                Button("Cancel") {
                    Haptics.soft()
                    remote.disconnect()
                }
                .buttonStyle(.cueSecondary(.medium, expands: false))
                .accessibilityIdentifier("remote.cancelButton")
                .padding(.top, 6)
            }
        case .linked(let name):
            VStack(spacing: 18) {
                connected(name, detail: String(localized: "Press play on \(name): the text starts here."))
                Button("Disconnect") {
                    HapticPatterns.playRemoteDisconnect()
                    remote.disconnect()
                }
                .buttonStyle(.cueDestructiveTinted(.large))
                .accessibilityIdentifier("remote.disconnectButton")
            }
        case .remote:
            VStack(spacing: 18) {
                if let name = remote.state.deviceName {
                    connected(name, detail: String(localized: "This device is a remote right now."))
                } else {
                    headline(title: remote.state.label, detail: String(localized: "This device is a remote right now."))
                }
                HStack(spacing: 10) {
                    Button("Open remote") { presentation.openRemoteController() }
                        .buttonStyle(.cuePrimary(.large))
                    Button("Stop") {
                        HapticPatterns.playRemoteDisconnect()
                        remote.disconnect()
                    }
                    .buttonStyle(.cueSecondary(.large, expands: false))
                }
            }
        }
    }

    private func headline(title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    /// CONNECTED in green over the other device's name.
    private func connected(_ name: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text("Connected")
                .font(.footnote.weight(.bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.successText)
            Text(verbatim: name)
                .font(.title2.bold())
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("remote.connected")
    }

    private var comingNext: some View {
        VStack(alignment: .leading, spacing: 8) {
            CueSectionHeader("Coming next")
                .padding(.horizontal, Metrics.textGutter)
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
                Text("Keyboards and foot pedals").foregroundStyle(Palette.ink2)
                Spacer(minLength: 8)
                Text("Soon")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(Palette.separator, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}
