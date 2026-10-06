//
//  SearchField.swift
//  Cue Studio
//

import SwiftUI

/// A capsule search field that sits in the content, for screens where something has to come above
/// the search (the navigation bar's drawer is always first). The screen holds its focus (`isFocused`), so it
/// knows when the keyboard is the search's.
struct SearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey
    var isFocused: FocusState<Bool>.Binding

    private static let height: CGFloat = 40

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            // The prompt in `ink2`, measured like any text (the system's placeholder grey is about 2.4:1 on the capsule).
            TextField(text: $text, prompt: Text(prompt).foregroundStyle(Palette.ink2)) { Text(prompt) }
                .font(.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .focused(isFocused)
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
        .onTapGesture { isFocused.wrappedValue = true }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var isFocused: Bool
    SearchField(text: $text, prompt: "Search scripts", isFocused: $isFocused)
        .padding()
        .background(Palette.bg)
}
#endif
