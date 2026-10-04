//
//  ScriptFilterMenu.swift
//  Cue Studio
//

import SwiftUI

/// "All ⌄" next to Recent: every script, one platform's, or one folder's.
struct ScriptFilterMenu: View {
    let filters: [ScriptFilter]
    @Binding var selection: ScriptFilter

    var body: some View {
        Menu {
            ForEach(filters, id: \.self) { filter in
                Button {
                    selection = filter
                } label: {
                    if selection == filter {
                        Label(filter.label, systemImage: "checkmark")
                    } else {
                        Text(filter.label)
                    }
                }
                .accessibilityIdentifier("scripts.filter.\(filter.identifier)")
            }
        } label: {
            HStack(spacing: 6) {
                if case .platform(let platform) = selection { ColorDot(color: platform.tint, size: 7) }
                Text(selection.label)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .accessibilityLabel(Text("Filter"))
        .accessibilityValue(Text(selection.label))
        .accessibilityIdentifier("scripts.filterMenu")
    }
}

private extension ScriptFilter {
    var identifier: String {
        switch self {
        case .all: "all"
        case .platform(let platform): platform.rawValue
        case .folder(let name): "folder.\(name)"
        }
    }
}
