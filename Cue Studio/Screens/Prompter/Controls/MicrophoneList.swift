//
//  MicrophoneList.swift
//  Cue Studio
//

import SwiftUI

/// The microphones for this recording, the same list wherever the recorder offers them (the microphone pill's sheet and Camera ›
/// Recording): Automatic first, then the one chosen when it isn't connected now (it is still the choice; takes use another until it is
/// back), then the inputs connected now. Picking one is for this take (`SessionSetupService.camera`); the usual mic is in Settings ›
/// Recording.
struct MicrophoneList: View {
    /// After a pick (the pill's sheet closes).
    var onPick: () -> Void = {}

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio

    var body: some View {
        let chosen = session.camera.microphoneID
        GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
            row(
                title: String(localized: "Automatic"), detail: String(localized: "Uses the connected mic, or the iPhone's"),
                isSelected: chosen == nil, identifier: "audioInput.automatic"
            ) { select(nil) }
            if let missing = missingMicrophone {
                row(
                    title: missing, detail: String(localized: "Not connected right now"), isSelected: true, identifier: "audioInput.missing"
                ) {}
            }
            ForEach(audio.inputs) { input in
                row(title: input.name, detail: input.detail, isSelected: chosen == input.id, identifier: "audioInput.option") {
                    select(input)
                }
            }
        }
        // A container of its own, so the list's identifier doesn't replace the rows'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("audioInput.list")
    }

    /// The chosen mic's name, while it isn't connected.
    private var missingMicrophone: String? {
        let camera = session.camera
        guard let id = camera.microphoneID, !audio.inputs.contains(where: { $0.id == id }) else { return nil }
        return camera.microphoneName ?? String(localized: "Microphone")
    }

    private func row(
        title: String, detail: String, isSelected: Bool, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title).foregroundStyle(Palette.ink)
                    Text(detail).cueFont(.footnote).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Palette.accText)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func select(_ input: MicrophoneOption?) {
        var camera = session.camera
        camera.microphoneID = input?.id
        camera.microphoneName = input?.name
        session.camera = camera
        audio.select(input?.id)
        onPick()
    }
}
