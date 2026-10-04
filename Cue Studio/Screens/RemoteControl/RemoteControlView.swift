//
//  RemoteControlView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Creator Setup › Remote Control: pair another iPhone or iPad to control this
/// teleprompter, or make this device the remote of another one.
struct RemoteControlView: View {
    @Environment(RemoteControlService.self) private var remote
    @Environment(PresentationService.self) private var presentation
    @Environment(ToastService.self) private var toast

    @State private var isEnteringCode = false
    @State private var typedCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                RemoteStatusHero(state: remote.state, deviceName: remote.state.deviceName)
                    .padding(.bottom, 4)

                SectionHeading(text: String(localized: "Connect a Device"))
                    .padding(.horizontal, 4)
                RemotePairingPanel()
                    .surfaceCard()

                SectionHeading(text: String(localized: "Use this device as a remote"))
                    .padding(EdgeInsets(top: 14, leading: 4, bottom: 0, trailing: 4))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan the code on the teleprompter with the Camera, or enter it here.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        typedCode = ""
                        isEnteringCode = true
                    } label: {
                        Label("Enter a code", systemImage: "keyboard")
                    }
                    .buttonStyle(.cueSecondary())
                    .accessibilityIdentifier("remote.enterCodeButton")
                }
                .surfaceCard()

                Text("Keyboards, foot pedals and presentation remotes are coming next.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .background(Palette.bg)
        .navigationTitle("Remote Control")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Enter the code", isPresented: $isEnteringCode) {
            TextField("ABC 234", text: $typedCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Connect") { join() }
        } message: {
            Text("The six letters and numbers under the QR code on the teleprompter.")
        }
    }

    private func join() {
        guard remote.join(code: typedCode) else {
            toast.show(String(localized: "That code doesn't look right. Check it and try again."))
            return
        }
        presentation.openRemoteController()
    }
}

#if DEBUG
#Preview {
    NavigationStack { RemoteControlView() }
        .previewEnvironment()
}
#endif
