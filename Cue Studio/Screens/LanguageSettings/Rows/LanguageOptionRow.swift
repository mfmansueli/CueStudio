//
//  LanguageOptionRow.swift
//  Cue Studio
//

import SwiftUI

/// One choice in a language list: the name (in the language itself), a detail line and a yellow
/// checkmark on the selected one, like the system's language lists.
struct LanguageOptionRow: View {
    let title: String
    var detail: String?
    var status: String?
    var statusIsWarning = false
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Palette.ink)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                    }
                    if let status {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(statusIsWarning ? Palette.warn : Palette.ink3)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.acc)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    List {
        LanguageOptionRow(title: "Português (Brasil)", detail: "Portuguese (Brazil)", status: "Ready on this iPhone", isSelected: true, identifier: "preview") {}
        LanguageOptionRow(title: "ไทย", detail: "Thai", status: "Not available on this iPhone", statusIsWarning: true, isSelected: false, identifier: "preview") {}
    }
    .preferredColorScheme(.dark)
}
#endif
