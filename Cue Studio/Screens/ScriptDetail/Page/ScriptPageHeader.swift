//
//  ScriptPageHeader.swift
//  Cue Studio
//

import SwiftUI

/// The title (a field, 27 pt). How long the script is lives in the length bar (`ScriptLengthBar`), once, not here too. The same while
/// the AI writes (only the title can't be edited then), so the page doesn't move when it ends; its Stop is in the state strip. While the
/// AI writes, its title arrives word by word out of the light (`WordsFromLight`, over the field, which keeps the room).
struct ScriptPageHeader: View {
    @Binding var title: String
    let isWriting: Bool
    var focus: FocusState<ScriptPageFocus?>.Binding
    let onSubmitTitle: () -> Void

    /// The AI's title is arriving (once it is written, it is the field's again).
    private var arrivesTitle: Bool { isWriting && !title.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Untitled", text: $title, axis: .vertical)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .focused(focus, equals: .title)
                .submitLabel(.next)
                .onSubmit(onSubmitTitle)
                .disabled(isWriting)
                .opacity(arrivesTitle ? 0 : 1)
                .overlay(alignment: .topLeading) {
                    if arrivesTitle {
                        WordsFromLight(text: title, font: .system(size: 27, weight: .bold), color: Palette.ink, stagger: 0.09)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityIdentifier("page.titleField")
        }
    }
}
