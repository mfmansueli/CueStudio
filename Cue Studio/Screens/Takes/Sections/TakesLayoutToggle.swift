//
//  TakesLayoutToggle.swift
//  Cue Studio
//

import SwiftUI

/// List | Grid in the navigation bar: the system's segmented control, with an icon per segment.
struct TakesLayoutToggle: View {
    @Binding var layout: TakeLayout

    var body: some View {
        Picker("Layout", selection: $layout) {
            ForEach([TakeLayout.list, .grid]) { option in
                Image(systemName: option.systemImage)
                    .accessibilityLabel(Text(option.label))
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityIdentifier("takes.layout")
    }
}
