//
//  TranslatedLineRow.swift
//  Cue Studio
//

import SwiftUI

/// A translated line under its original, written in place. What's typed is kept when the field is
/// left (one undo step per line, not per letter). An outdated line says so and can be kept as is.
struct TranslatedLineRow: View {
    let original: String
    let text: String
    let isOutdated: Bool
    let onCommit: (String) -> Void
    let onKeep: () -> Void

    @State private var draft = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(original)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
            TextField("Translation", text: $draft, axis: .vertical)
                .focused($isEditing)
                .onSubmit(commit)
                .accessibilityIdentifier("translation.line")
            if isOutdated {
                HStack(spacing: 8) {
                    TagPill(text: String(localized: "Outdated"), dotColor: Palette.warn)
                    Button("Still right", action: onKeep)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("translation.keepButton")
                }
            }
        }
        .onAppear { draft = text }
        .onChange(of: text) { _, new in if !isEditing { draft = new } }
        .onChange(of: isEditing) { _, editing in if !editing { commit() } }
    }

    private func commit() {
        guard draft != text else { return }
        onCommit(draft)
    }
}
