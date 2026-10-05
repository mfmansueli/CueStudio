//
//  ScriptPageHeader.swift
//  Cue Studio
//

import SwiftUI

/// The title (a field, 27 pt) and the mono meter under it: "113 WORDS · ~0:45", and, while the AI
/// writes, "✦ WRITING IN YOUR VOICE…" with a Stop.
struct ScriptPageHeader: View {
    @Binding var title: String
    let wordsAndTime: String
    let isWriting: Bool
    var focus: FocusState<ScriptPageFocus?>.Binding
    let onStop: () -> Void
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
            HStack(spacing: 8) {
                Text(wordsAndTime)
                    .foregroundStyle(Palette.accText)
                    .accessibilityIdentifier("page.meter")
                if isWriting {
                    Spacer(minLength: 0)
                    Button(action: onStop) {
                        Text("Stop")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.cueAI(.compact, expands: false))
                    .accessibilityIdentifier("page.stopButton")
                }
            }
            .font(CueStudioFont.hud)
            .textCase(.uppercase)
            .tracking(0.6)
        }
    }
}
