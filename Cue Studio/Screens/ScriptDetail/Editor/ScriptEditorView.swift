//
//  ScriptEditorView.swift
//  Cue Studio
//

import SwiftUI

/// Edit mode: title, structure and the text, with tools above the keyboard.
struct ScriptEditorView: View {
    @Bindable var viewModel: ScriptDetailViewModel
    let script: Script

    @FocusState private var focus: Field?

    private enum Field { case title, text }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Untitled script", text: $viewModel.draftTitle, axis: .vertical)
                .font(.title2.bold())
                .foregroundStyle(Palette.ink)
                .lineLimit(1...2)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .text }
                .padding(.horizontal, Metrics.textGutter)
                .padding(.top, 8)
                .accessibilityIdentifier("editor.titleField")
            ScriptMetaRow(
                platform: script.platform,
                formatLabel: viewModel.structure.label,
                preset: viewModel.preset,
                onDestination: { viewModel.sheet = .destination }
            )
            .padding(.horizontal, Metrics.textGutter)
            .padding(.top, 4)
            BlockStripView(
                summaries: viewModel.summaries,
                isSerious: viewModel.structure.isSerious,
                hookRunsLong: viewModel.hookOverrun != nil,
                onHookTap: { viewModel.sheet = .hooks }
            )
            .padding(.top, 4)
            Rectangle()
                .fill(Palette.separator)
                .frame(height: 0.5)
                .padding(.horizontal, Metrics.textGutter)
                .padding(.top, 10)
            ZStack(alignment: .topLeading) {
                if viewModel.draftText.isEmpty {
                    Text("Start writing what you want to say… Add cues like [pause] or [smile].")
                        .font(.system(size: 19))
                        .foregroundStyle(Palette.ink3)
                        .padding(.horizontal, Metrics.textGutter + 5)
                        .padding(.top, 16 + 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.draftText)
                    .font(.system(size: 19))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.ink.opacity(0.92))
                    .tint(Palette.acc)
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .text)
                    .padding(.horizontal, Metrics.textGutter)
                    .padding(.top, 16)
                    .accessibilityLabel(Text("Script text"))
                    .accessibilityIdentifier("editor.textEditor")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorToolsPanel(viewModel: viewModel)
        }
        .onAppear {
            focus = script.title.isEmpty && script.isEmpty ? .title : .text
        }
    }
}
