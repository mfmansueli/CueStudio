//
//  ImproveScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Improve script": the tools of the script's format (and "In my voice") as a list, with a tip
/// first when the opening runs long. Everything runs on the iPhone; a tool changes the script and
/// the toast offers Undo.
struct ImproveScriptSheet: View {
    let viewModel: ScriptDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(
                    title: String(localized: "Improve script"),
                    subtitle: String(localized: "Apple Intelligence · runs on your iPhone"),
                    onClose: { dismiss() }
                )
                if let overrun = viewModel.hookOverrun {
                    hookTip(overrun)
                }
                GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 62) {
                    ForEach(viewModel.tools) { tool in
                        row(tool)
                    }
                }
                if viewModel.needsFactCheck {
                    Text("Apple Intelligence · Check facts before recording")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
    }

    /// "Your hook runs ~12s" with what to aim for: opens the hook options.
    private func hookTip(_ overrun: TimeInterval) -> some View {
        Button {
            Task { await viewModel.openHooks() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.warnText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your hook runs ~\(DurationText.short(overrun))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Aim for about 3s. See shorter openings.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.warnWash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.warnBorder, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("improve.hookTip")
    }

    private func row(_ tool: ScriptTool) -> some View {
        let isRunning = viewModel.runningTool == tool
        let dimmed = tool.needsLanguageModel && !viewModel.isLanguageModelAvailable
        let label = HStack(spacing: 12) {
            Group {
                if isRunning {
                    ProgressView().tint(Palette.accText)
                } else {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.accText)
                }
            }
            .frame(width: 34, height: 34)
            .background(Palette.accSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(tool.subtitle(idealRange: viewModel.preset.idealRange, platform: viewModel.script?.platform ?? .tiktok))
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
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
        .accessibilityIdentifier("improve.tool.\(tool.rawValue)")
    }
}
