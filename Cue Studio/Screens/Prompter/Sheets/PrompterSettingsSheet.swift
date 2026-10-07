//
//  PrompterSettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa" in the Selfie recorder (09 §11): the Prompter page of Settings, over the settings of this recording. Sized and dressed like the
/// camera's sheet (`CameraSettingsSheet`): no taller than `maxHeight`, so the text window above stays in sight and a change shows on it as
/// the creator makes it, on the same still background.
struct PrompterSettingsSheet: View {
    /// Tallest the sheet may grow, so the script above it stays readable. `nil` lets it go from medium to large.
    var maxHeight: CGFloat?

    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var session = session
        let bindings = SettingsBindings(prompter: $session.prompter, camera: $session.camera)
        NavigationStack {
            SettingsPrompterView(bindings: bindings, activeMode: .selfie, isRecorderSheet: true)
                .navigationDestination(for: SettingsRoute.self) { SettingsDestination(route: $0, bindings: bindings) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                            .accessibilityIdentifier("display.doneButton")
                    }
                }
        }
        .presentationDetents(maxHeight.map { [.height($0)] } ?? [.medium, .large])
        .presentationBackground(Palette.surface)
        .presentationBackgroundInteraction(maxHeight.map { .enabled(upThrough: .height($0)) } ?? .enabled)
    }
}
