//
//  SetupRow.swift
//  Cue Studio
//

import SwiftUI

/// A Creator Setup row: what it is, a line on what it means, and the control underneath or beside it.
struct SetupRow<Control: View>: View {
    let title: String
    var detail: String?
    /// Controls wider than a switch (chips, tiles) go under the title.
    var stacksControl = true
    /// The place the chips of Settings › Prompter scroll to.
    var anchor: PrompterSettingsSection?
    @ViewBuilder var control: Control

    var body: some View {
        Group {
            if stacksControl {
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    control
                }
                .padding(.vertical, 14)
            } else {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 8)
                    control
                }
                .frame(minHeight: 58)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            if let anchor { Color.clear.frame(height: 1).id(anchor) }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(Palette.ink)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview {
    GroupedCard {
        SetupRow(title: "Camera", detail: "Where every recording starts") {
            HStack { FilterChip(label: "Front", isSelected: true); FilterChip(label: "Back", isSelected: false) }
        }
        SetupRow(title: "Mirror text", stacksControl: false) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
    }
    .padding()
    .background(Palette.bg)
}
#endif
