//
//  PermissionsView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Privacy & AI data › Permissions: what the creator allowed. Cue asks only when a feature needs it; changing an answer
/// is the iPhone's Settings to do.
struct PermissionsView: View {
    @Environment(PermissionsService.self) private var permissions
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                row(String(localized: "Camera"), state(permissions.camera), "camera")
                row(String(localized: "Microphone"), state(permissions.microphone), "microphone")
                row(String(localized: "Speech recognition"), state(permissions.speech), "speech")
                row(String(localized: "Photos"), photosLabel, "photos")
            } footer: {
                Text("Cue asks only when a feature needs it.")
            }
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Open iPhone Settings")
                        .foregroundStyle(Palette.accText)
                        .frame(minHeight: Metrics.listRowContent)
                }
                .accessibilityIdentifier("settings.openIPhoneSettings")
                .cardRowBackground()
            }
        }
        .cueGroupedList()
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { permissions.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { permissions.refresh() }
        }
    }

    private func row(_ title: String, _ value: String, _ id: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(Palette.ink2)
        }
        .frame(minHeight: Metrics.listRowContent)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.permission.\(id)")
        .cardRowBackground()
    }

    private func state(_ state: PermissionState) -> String {
        switch state {
        case .allowed: String(localized: "Allowed")
        case .denied: String(localized: "Off")
        case .notAsked: String(localized: "Not asked yet")
        }
    }

    private var photosLabel: String {
        switch permissions.photos {
        case .addOnly: String(localized: "Add only")
        case .full: String(localized: "Allowed")
        case .denied: String(localized: "Off")
        case .notAsked: String(localized: "Not asked yet")
        }
    }
}
