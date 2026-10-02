//
//  AIToolsPanel.swift
//  Cue Studio
//

import SwiftUI

/// "Improve with AI": the tools of the script's format as a grid of buttons. A tool rewrites the
/// draft on the iPhone and the editor says what it did, with Undo.
struct AIToolsPanel: View {
    let viewModel: ScriptDetailViewModel

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorPanelHeader(title: String(localized: "Improve with AI"), detail: String(localized: "Apple Intelligence · on device"))
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.tools) { tool in
                    button(tool)
                }
            }
        }
        .accessibilityIdentifier("editor.panel.ai")
    }

    private func button(_ tool: ScriptTool) -> some View {
        let isRunning = viewModel.runningTool == tool
        let dimmed = tool.needsLanguageModel && !viewModel.isLanguageModelAvailable
        let label = HStack(spacing: 10) {
            if isRunning {
                ProgressView().controlSize(.small).tint(Palette.accText)
            } else {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.accText)
                    .frame(width: 20)
            }
            Text(tool.label)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        return Group {
            if tool == .translate {
                Menu {
                    ForEach(viewModel.translationLanguages) { language in
                        Button(language.localizedName) { Task { await viewModel.run(.translate, language: language) } }
                    }
                } label: {
                    label
                }
            } else {
                Button {
                    Task { await viewModel.run(tool) }
                } label: {
                    label
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(dimmed ? 0.5 : 1)
        .disabled(viewModel.runningTool != nil)
        .accessibilityHint(dimmed ? Text("Requires Apple Intelligence") : Text(""))
        .accessibilityIdentifier("editor.tool.\(tool.rawValue)")
    }
}
