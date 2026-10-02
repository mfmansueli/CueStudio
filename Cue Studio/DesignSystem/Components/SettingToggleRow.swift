//
//  SettingToggleRow.swift
//  Cue Studio
//

import SwiftUI

/// A settings row inside a grouped card: a title, an optional line of detail and a green switch.
struct SettingToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool
    var minHeight: CGFloat = 58

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.successText)
        .frame(minHeight: minHeight)
        .padding(.horizontal, 16)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var isOn = true
    GroupedCard(background: Palette.surface2, radius: 22) {
        SettingToggleRow(title: "Show safe zone", detail: "Instagram Reels · buttons, caption & header", isOn: $isOn)
    }
    .padding()
    .background(Palette.bg)
}
#endif
