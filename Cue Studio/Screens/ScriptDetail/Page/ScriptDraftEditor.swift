//
//  ScriptDraftEditor.swift
//  Cue Studio
//

import SwiftUI

/// "Draft": the words as one free page. Nothing to fill in; cues are written in brackets.
struct ScriptDraftEditor: View {
    @Binding var text: String
    @Binding var selection: TextSelection?
    let textSize: ScriptTextSize
    let isLocked: Bool
    var focus: FocusState<ScriptPageFocus?>.Binding
    let onEdit: () -> Void

    @ScaledMetric(relativeTo: .body) private var minimumHeight = 340.0

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .font(.system(size: textSize.points))
            .lineSpacing(6)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accText)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .focused(focus, equals: .text)
            .readOnly(isLocked)
            .frame(minHeight: minimumHeight, alignment: .top)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Just start talking… shape it later.")
                        .font(.system(size: textSize.points))
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .writingToolsBehavior(.limited)
            .onChange(of: text) { onEdit() }
            .accessibilityLabel(Text("Script text"))
            .accessibilityIdentifier("page.draftEditor")
    }
}

private extension View {
    /// Typing is off while the AI is writing into the page.
    func readOnly(_ isLocked: Bool) -> some View {
        allowsHitTesting(!isLocked)
    }
}
