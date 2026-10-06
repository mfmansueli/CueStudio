//
//  EditorToolPanel.swift
//  Cue Studio
//

import SwiftUI

/// The panel that stands in for the keyboard under the writing area, as tall as the keyboard was
/// so the text doesn't jump when one replaces the other.
struct EditorToolPanel: View {
    @Bindable var viewModel: ScriptDetailViewModel
    @Binding var textSize: ScriptTextSize
    let tool: EditorTool
    let height: CGFloat

    var body: some View {
        ScrollView {
            Group {
                switch tool {
                case .ai: AIToolsPanel(viewModel: viewModel)
                case .cues: CuesPanel(viewModel: viewModel)
                case .sections: SectionsPanel(viewModel: viewModel)
                case .options: OptionsPanel(viewModel: viewModel, textSize: $textSize)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Palette.Editor.panel)
        .transition(.opacity)
    }
}
