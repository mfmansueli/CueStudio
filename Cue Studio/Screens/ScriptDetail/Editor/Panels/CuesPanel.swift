//
//  CuesPanel.swift
//  Cue Studio
//

import SwiftUI

/// Cues: stage directions put in at the caret between square brackets. The panel stays open, so
/// several go in one after another.
struct CuesPanel: View {
    let viewModel: ScriptDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorPanelHeader(title: String(localized: "Cues"), detail: String(localized: "Inserted at the cursor · not read aloud"))
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ScriptCue.allCases) { cue in
                    Button {
                        viewModel.insertCue(cue)
                        Haptics.selection()
                    } label: {
                        Text(cue.name)
                            .font(.system(.footnote, weight: .bold))
                            .textCase(.uppercase)
                            .kerning(1)
                            .foregroundStyle(Palette.accText)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Palette.accSoft, in: Capsule())
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editor.cue.\(cue.name)")
                }
            }
        }
        .accessibilityIdentifier("editor.panel.cues")
    }
}
