//
//  RemoteJoinFlow.swift
//  Cue Studio
//

import SwiftUI

/// Making this iPhone the remote of another one: the code typed into an alert, or read by the camera (`QRScannerSheet`), then the
/// remote opens; a code that doesn't read says so. Shared by Settings › Remote's cards (`RemoteJoinCards`) and its rows in Settings'
/// search (`RemoteEntryRow`).
struct RemoteJoinFlow: ViewModifier {
    @Binding var isEnteringCode: Bool
    @Binding var isScanning: Bool

    @Environment(RemoteControlService.self) private var remote
    @Environment(PresentationService.self) private var presentation
    @Environment(ToastService.self) private var toast
    @State private var typedCode = ""

    func body(content: Content) -> some View {
        content
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
            .onChange(of: isEnteringCode) { _, isOpen in
                if isOpen { typedCode = "" }
            }
    }

    private func join(_ text: String) {
        guard remote.join(code: text) else {
            Haptics.rigid()
            toast.show(String(localized: "Wrong code · Try again"))
            return
        }
        presentation.openRemoteController()
    }
}

extension View {
    /// This iPhone joining another as its remote, by a typed code (`isEnteringCode`) or a scanned one (`isScanning`).
    func remoteJoinFlow(isEnteringCode: Binding<Bool>, isScanning: Binding<Bool>) -> some View {
        modifier(RemoteJoinFlow(isEnteringCode: isEnteringCode, isScanning: isScanning))
    }
}
