//
//  ScriptEditorHeader.swift
//  Cue Studio
//

import SwiftUI

/// The top of the writing screen: the title to type in, a line saying how long the script reads,
/// and Done. Nothing else competes with the text.
struct ScriptEditorHeader: View {
    @Bindable var viewModel: ScriptDetailViewModel

    @FocusState private var titleHasFocus: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                TextField("Untitled script", text: $viewModel.draftTitle)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.accText)
                    .lineLimit(1)
                    .focused($titleHasFocus)
                    .submitLabel(.next)
                    .onSubmit { viewModel.focus = .at(0, offset: 0) }
                    .accessibilityIdentifier("editor.titleField")
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.statusIsInRange ? Palette.acc : Palette.warn)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(viewModel.statusLine)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("editor.status")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                viewModel.finishEditing()
            } label: {
                Text("Done")
            }
            .buttonStyle(.cuePrimary(.compact, expands: false))
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityIdentifier("editor.doneButton")
        }
        .padding(.leading, Metrics.textGutter)
        .padding(.trailing, 14)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.separator).frame(height: 0.5)
        }
        .onAppear {
            // A new script starts on its title; one with words in it, in the words.
            if viewModel.draftTitle.isEmpty, viewModel.draftText.isEmpty { titleHasFocus = true }
        }
        .onChange(of: titleHasFocus) { _, hasFocus in
            viewModel.isTitleFocused = hasFocus
        }
        // The caret moving to a paragraph, or the keyboard being put away, takes it off the title.
        .onChange(of: viewModel.focus) { _, _ in
            if titleHasFocus { titleHasFocus = false }
        }
    }
}
