//
//  SearchField.swift
//  Cue Studio
//

import SwiftUI

/// A capsule search field that sits in the content, for screens where something has to come above
/// the search (the navigation bar's drawer is always first).
struct SearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey

    @FocusState private var isFocused: Bool

    private static let height: CGFloat = 40

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .font(.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.acc)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityAddTraits(.isSearchField)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.ink3)
                        .frame(width: Self.height, height: Self.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, text.isEmpty ? 12 : 0)
        .frame(height: Self.height)
        .background(Palette.fill, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var text = ""
    SearchField(text: $text, prompt: "Search scripts")
        .padding()
        .background(Palette.bg)
}
#endif
