//
//  RemoteControllerView.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// This device as the remote of a teleprompter on another one: play, pause, speed and moving
/// through the script, with what the teleprompter reports (script, progress, speed). Opens from a
/// scanned pairing code or a typed one.
struct RemoteControllerView: View {
    @Environment(RemoteControlService.self) private var remote
    @Environment(\.dismiss) private var dismiss

    private var status: RemoteStatus? { remote.teleprompterStatus }
    private var canControl: Bool { remote.isConnected && status?.scriptTitle != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 24)
            if remote.isConnected {
                scriptCard
            } else {
                searching
            }
            Spacer(minLength: 24)
            controls
        }
        .padding(EdgeInsets(top: 12, leading: Metrics.textGutter, bottom: 24, trailing: Metrics.textGutter))
        .background(Palette.bg.ignoresSafeArea())
        .task {
            // A remote on a stand must not go to sleep mid-take.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button {
                remote.disconnect()
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.cueIcon(.surface, diameter: 40))
            .accessibilityLabel(Text("Close remote"))
            .accessibilityIdentifier("remoteController.closeButton")
            Spacer()
            VStack(spacing: 2) {
                Text("Remote").font(.headline)
                HStack(spacing: 6) {
                    ColorDot(color: remote.isConnected ? Palette.success : Palette.ink3, size: 6)
                    Text(remote.state.deviceName ?? remote.state.label)
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("remoteController.status")
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
    }

    private var searching: some View {
        VStack(spacing: 12) {
            if case .failed(let message) = remote.state {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(Palette.warn)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView().controlSize(.large).tint(Palette.ink2)
                Text(remote.state.label).font(.headline)
                Text("Keep both devices close, with Wi-Fi on.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var scriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status?.scriptTitle ?? String(localized: "Open a script on the teleprompter"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(status?.scriptTitle == nil ? Palette.ink2 : Palette.ink)
                .lineLimit(2)
            if let status, status.scriptTitle != nil {
                UsageMeter(fraction: status.progress, color: Palette.acc, height: 4, animated: true)
                HStack {
                    if status.isRecording {
                        Label("Recording", systemImage: "record.circle")
                            .foregroundStyle(Palette.record)
                    } else {
                        Text(status.isPlaying ? "Playing" : "Paused")
                            .foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    Text(status.followsVoice ? String(localized: "Voice Following") : status.speedLabel)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink2)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("remoteController.scriptCard")
    }

    private var controls: some View {
        VStack(spacing: 22) {
            HStack {
                commandButton(.restart, systemImage: "arrow.up.to.line", variant: .surface, diameter: 56)
                Spacer()
                commandButton(.backward, systemImage: "chevron.backward.2", variant: .surface, diameter: 64)
                Spacer()
                commandButton(.togglePlay, systemImage: status?.isPlaying == true ? "pause.fill" : "play.fill", variant: .accent, diameter: 96)
                    .accessibilityLabel(Text(status?.isPlaying == true ? "Pause" : "Play"))
                Spacer()
                commandButton(.forward, systemImage: "chevron.forward.2", variant: .surface, diameter: 64)
                Spacer()
                Color.clear.frame(width: 56, height: 56)
            }
            HStack(spacing: 16) {
                commandButton(.slower, systemImage: "minus", variant: .surface, diameter: 56)
                VStack(spacing: 2) {
                    Text(status?.speedLabel ?? "–")
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                }
                .frame(minWidth: 80)
                .accessibilityElement(children: .combine)
                commandButton(.faster, systemImage: "plus", variant: .surface, diameter: 56)
            }
            .disabled(status?.followsVoice == true)
        }
        .disabled(!canControl)
    }

    private func commandButton(_ command: RemoteCommand, systemImage: String, variant: CueIconButtonStyle.Variant, diameter: CGFloat) -> some View {
        Button {
            remote.send(command)
        } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(.cueIcon(variant, diameter: diameter))
        .accessibilityLabel(Text(command.label))
        .accessibilityIdentifier("remoteController.\(command.rawValue)")
    }
}

#if DEBUG
#Preview {
    RemoteControllerView()
        .previewEnvironment()
}
#endif
