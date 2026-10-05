//
//  ScriptPageHeader.swift
//  Cue Studio
//

import SwiftUI

/// The title (a field, 27 pt) and the mono meter under it: "113 WORDS · ~0:45". The same while the AI writes (only the title can't be
/// edited then), so the page doesn't move when it ends; its Stop is in the state strip.
struct ScriptPageHeader: View {
    @Binding var title: String
    let wordsAndTime: String
    let isWriting: Bool
    var focus: FocusState<ScriptPageFocus?>.Binding
    let onSubmitTitle: () -> Void

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
                .accessibilityIdentifier("page.titleField")
            Text(wordsAndTime)
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.accText)
                .accessibilityIdentifier("page.meter")
        }
    }
}
