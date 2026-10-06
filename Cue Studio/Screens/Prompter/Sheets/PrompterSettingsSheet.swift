//
//  PrompterSettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa" in the Selfie recorder (09 §11): the Prompter page of Settings, over the settings of this recording. A medium sheet that
/// grows to large, with the camera behind it still alive, so a change shows on the text window as the creator makes it.
struct PrompterSettingsSheet: View {
    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var session = session
        let bindings = SettingsBindings(prompter: $session.prompter, camera: $session.camera)
        NavigationStack {
            SettingsPrompterView(bindings: bindings, activeMode: .selfie)
                .navigationDestination(for: SettingsRoute.self) { SettingsDestination(route: $0, bindings: bindings) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                            .accessibilityIdentifier("display.doneButton")
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled)
    }
}
