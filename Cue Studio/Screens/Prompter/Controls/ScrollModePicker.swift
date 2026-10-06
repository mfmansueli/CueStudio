//
//  ScrollModePicker.swift
//  Cue Studio
//

import SwiftUI

/// "Voice | Steady" at the top of the prompter's bars: the system's segmented control.
struct ScrollModePicker: View {
    let selection: ScrollMode
    let onSelect: (ScrollMode) -> Void

    var body: some View {
        Picker("Mode", selection: Binding(get: { selection }, set: { onSelect($0) })) {
            ForEach([ScrollMode.voice, .steady], id: \.self) { mode in
                Text(mode.shortLabel).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.large)
        .accessibilityIdentifier("prompter.scrollMode")
    }
}

#if DEBUG
#Preview {
    VStack {
        ScrollModePicker(selection: .voice, onSelect: { _ in })
        ScrollModePicker(selection: .steady, onSelect: { _ in })
    }
    .padding()
    .background(Color.black)
}
#endif
