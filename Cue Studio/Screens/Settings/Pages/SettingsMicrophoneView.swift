//
//  SettingsMicrophoneView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Recording › Microphone: Automatic, or one of the inputs connected now. A saved mic that isn't connected stays listed:
/// it is still the choice, and takes use another one until it's back.
struct SettingsMicrophoneView: View {
    @Environment(PreferencesService.self) private var preferences
    @Environment(AudioInputManager.self) private var audio

    var body: some View {
        List {
            Section {
                option(
                    title: String(localized: "Automatic"), detail: String(localized: "A connected mic, or the iPhone's"),
                    isSelected: preferences.camera.microphoneID == nil, id: "automatic"
                ) {
                    select(nil)
                }
                if let missing = missingMicrophone {
                    option(title: missing.name, detail: String(localized: "Not connected right now"), isSelected: true, id: "missing") {}
                }
                ForEach(audio.inputs) { input in
                    option(title: input.name, detail: nil, isSelected: preferences.camera.microphoneID == input.id, id: input.id) {
                        select(input)
                    }
                }
            } footer: {
                Text("Plug in or pair a mic and it shows up here.")
            }
        }
        .cueGroupedList()
        .navigationTitle("Microphone")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
        .onAppear { audio.refreshInputs() }
    }

    /// The saved mic, while it isn't connected.
    private var missingMicrophone: (id: String, name: String)? {
        guard let id = preferences.camera.microphoneID, !audio.inputs.isEmpty, !audio.inputs.contains(where: { $0.id == id }) else { return nil }
        return (id, preferences.camera.microphoneName ?? String(localized: "Microphone"))
    }

    private func option(title: String, detail: String?, isSelected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).foregroundStyle(Palette.ink)
                    if let detail { Text(detail).font(.footnote).foregroundStyle(Palette.ink2) }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.accText)
                }
            }
            .frame(minHeight: Metrics.listRowContent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings.microphoneOption.\(id)")
        .cardRowBackground()
    }

    private func select(_ input: MicrophoneOption?) {
        preferences.camera.microphoneID = input?.id
        preferences.camera.microphoneName = input?.name
    }
}
