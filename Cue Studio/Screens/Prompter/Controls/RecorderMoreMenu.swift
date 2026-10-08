//
//  RecorderMoreMenu.swift
//  Cue Studio
//

import SwiftUI

/// The "•••" at the end of the capture row: Countdown (a small yellow badge on the button says
/// how long, when it is on), Remote Control and "This take". The countdown and the take's setup
/// can't change while it records or counts down; the remote can.
struct RecorderMoreMenu: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        let countdown = session.camera.countdown
        Menu {
            Picker(selection: countdownBinding) {
                ForEach(Countdown.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                Label("Countdown", systemImage: "timer")
            }
            .disabled(!viewModel.canChangeSetup)
            Button { viewModel.openRemoteControl() } label: {
                Label("Remote Control", systemImage: "iphone.radiowaves.left.and.right")
            }
            .accessibilityIdentifier("prompter.moreRemote")
            Button { viewModel.openRecordingSetup() } label: {
                Label("This take", systemImage: "slider.horizontal.3")
            }
            .disabled(!viewModel.canChangeSetup)
            .accessibilityIdentifier("prompter.moreThisTake")
        } label: {
            Text("•••")
                .font(.system(size: 15, weight: .bold))
                .tracking(1)
        }
        // Liquid Glass, like the round buttons beside it.
        .glassIconButton()
        .overlay(alignment: .topTrailing) {
            if countdown != .off {
                Text(countdown.shortLabel)
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.accInk)
                    .padding(.horizontal, 4)
                    .frame(height: 16)
                    .background(Palette.acc, in: Capsule())
                    .offset(x: 6, y: -4)
            }
        }
        .menuOrder(.fixed)
        .accessibilityLabel(Text("More"))
        .accessibilityValue(countdown == .off ? Text("") : Text(countdown.label))
        .accessibilityIdentifier("prompter.moreButton")
    }

    private var countdownBinding: Binding<Countdown> {
        Binding(get: { session.camera.countdown }, set: { session.camera.countdown = $0 })
    }
}
