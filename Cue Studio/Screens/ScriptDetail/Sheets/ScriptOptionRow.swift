//
//  ScriptOptionRow.swift
//  Cue Studio
//

import SwiftUI

/// A row of Script details: a name, what it's set to and a chevron, opening the
/// sheet that changes it.
struct ScriptOptionRow<Value: View>: View {
    let title: String
    let identifier: String
    let action: () -> Void
    @ViewBuilder var value: Value

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                value
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
