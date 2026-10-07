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
                let missing = missingMicrophone
                let leading = missing == nil ? 1 : 2
                let count = leading + audio.inputs.count
                option(
                    title: String(localized: "Automatic"), detail: String(localized: "A connected mic, or the iPhone's"),
                    isSelected: preferences.camera.microphoneID == nil, id: "automatic", position: CardRowPosition(index: 0, count: count)
                ) {
                    select(nil)
                }
                if let missing {
                    option(
                        title: missing.name, detail: String(localized: "Not connected right now"), isSelected: true, id: "missing",
                        position: CardRowPosition(index: 1, count: count)
                    ) {}
                }
                ForEach(Array(audio.inputs.enumerated()), id: \.element.id) { index, input in
                    option(
                        title: input.name, detail: nil, isSelected: preferences.camera.microphoneID == input.id, id: input.id,
                        position: CardRowPosition(index: leading + index, count: count)
                    ) {
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

    private func option(
        title: String, detail: String?, isSelected: Bool, id: String, position: CardRowPosition, action: @escaping () -> Void
    ) -> some View {
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
        .cardRowBackground(position: position)
    }

    private func select(_ input: MicrophoneOption?) {
        preferences.camera.microphoneID = input?.id
        preferences.camera.microphoneName = input?.name
    }
}
