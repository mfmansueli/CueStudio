//
//  ModeSwitcher.swift
//  Cue Studio
//

import SwiftUI

/// Selfie | Studio over the camera: the system's segmented control, the same as Camera | Recording in the camera sheet's bar.
struct ModeSwitcher: View {
    let mode: PrompterMode
    let onChange: (PrompterMode) -> Void

    var body: some View {
        Picker("Mode", selection: Binding(get: { mode }, set: { onChange($0) })) {
            ForEach(PrompterMode.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityIdentifier("prompter.mode")
        // The mode names never truncate; the platform chip beside them gives way first.
        .layoutPriority(1)
    }
}

#if DEBUG
#Preview {
    ModeSwitcher(mode: .selfie, onChange: { _ in })
        .padding()
        .background(CameraFeedPlaceholder())
}
#endif
