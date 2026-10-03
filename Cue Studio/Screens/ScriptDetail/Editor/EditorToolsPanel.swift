//
//  EditorToolsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Sits above the keyboard while editing: version notice, one-tap tools and the length meter.
struct EditorToolsPanel: View {
    let viewModel: ScriptDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let notice = viewModel.versionNotice {
                Label(notice, systemImage: "arrow.triangle.branch")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.info)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .background(Palette.infoSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, Metrics.gutter)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if viewModel.undoText != nil {
                        Button {
                            viewModel.undoRewrite()
                        } label: {
                            toolLabel(String(localized: "Undo"), systemImage: "arrow.uturn.backward", isRunning: false)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(viewModel.tools) { tool in
                        toolButton(tool)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            LengthMeterView(zone: viewModel.zone)
                .padding(.horizontal, Metrics.gutter)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Palette.toolsPanel)
                .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func toolButton(_ tool: ScriptTool) -> some View {
        let isRunning = viewModel.runningTool == tool
        let dimmed = tool.needsLanguageModel && !viewModel.isLanguageModelAvailable
        Group {
            if tool == .translate {
                Menu {
                    ForEach(viewModel.translationLanguages) { language in
                        Button(language.label) { Task { await viewModel.run(.translate, language: language) } }
                    }
                } label: {
                    toolLabel(tool.label, systemImage: "sparkles", isRunning: isRunning)
                }
            } else {
                Button {
                    Task { await viewModel.run(tool) }
                } label: {
                    toolLabel(tool.label, systemImage: "sparkles", isRunning: isRunning)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(dimmed ? 0.45 : 1)
        .disabled(viewModel.runningTool != nil)
        .accessibilityHint(dimmed ? Text("Requires Apple Intelligence") : Text(""))
        .accessibilityIdentifier("editor.tool.\(tool.rawValue)")
    }

    private func toolLabel(_ title: String, systemImage: String, isRunning: Bool) -> some View {
        HStack(spacing: 6) {
            if isRunning {
                ProgressView().controlSize(.mini).tint(Palette.acc)
            } else {
                Image(systemName: systemImage).font(.caption.weight(.bold))
            }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.acc)
        .padding(.horizontal, 13)
        .frame(height: Metrics.chipHeight)
        .background(Palette.acc.opacity(0.1), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.28), lineWidth: 0.5))
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Capsule())
    }
}
