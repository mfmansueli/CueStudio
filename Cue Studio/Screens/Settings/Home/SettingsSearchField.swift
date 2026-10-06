//
//  SettingsSearchField.swift
//  Cue Studio
//

import SwiftUI

/// The search of Settings (11.1): a 36 pt pill under the large title, a magnifier, "Search" and, once something is typed, a round ✕ that clears it.
struct SettingsSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink2)
            TextField("Search", text: $text)
                .font(.system(size: 17))
                .foregroundStyle(Palette.ink)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("settings.searchField")
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Palette.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.white.opacity(0.1), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }
}
