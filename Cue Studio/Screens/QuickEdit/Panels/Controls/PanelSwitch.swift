//
//  PanelSwitch.swift
//  Cue Studio
//

import SwiftUI

/// The green switch of the panels, drawn alone (in a row of controls) or in `PanelToggleRow`.
struct PanelSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Palette.success : Palette.toggleOff)
            .frame(width: 51, height: 31)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(Color.white).frame(width: 27, height: 27).padding(2)
            }
            .animation(.easeOut(duration: 0.18), value: isOn)
    }
}
