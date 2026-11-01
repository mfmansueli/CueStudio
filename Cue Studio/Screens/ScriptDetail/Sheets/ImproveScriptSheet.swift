//
//  ImproveScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Improve script": the tools of the script's format (and "In my voice") as a list, with a tip
/// first when the opening runs long. Every tool is Apple Intelligence's, whoever wrote the script; where it
/// can't draft this script only the tools that need no model are listed. A tool changes the script and the
/// toast offers Undo.
struct ImproveScriptSheet: View {
    let viewModel: ScriptDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // A script in a language Apple Intelligence can't draft in: the subtitle says so, and the tools that need it aren't there.
                SheetHeader(title: String(localized: "Improve script"), subtitle: subtitle)
                if let overrun = viewModel.hookOverrun {
                    hookTip(overrun)
                }
                if !viewModel.tools.isEmpty {
                    GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 62) {
                        ForEach(viewModel.tools) { tool in
                            row(tool)
                        }
                    }
                }
                if viewModel.needsFactCheck {
                    Text(viewModel.script?.draftedBy == .ultra
                        ? "Ultra AI · Check facts before recording" : "Apple Intelligence · Check facts before recording")
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
    }

    /// Who does the work, or why the tools that need it aren't there.
    private var subtitle: String? {
        if viewModel.canDraft { return String(localized: "Apple Intelligence · runs on your iPhone") }
        return viewModel.drafting.cause?.isLanguage == true ? viewModel.drafting.reason : nil
    }

    /// "Your hook runs ~12s" with what to aim for: opens the hook options.
    private func hookTip(_ overrun: TimeInterval) -> some View {
        Button {
            Task { await viewModel.openHooks() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "stopwatch")
                    .cueFont(20, weight: .medium)
                    .foregroundStyle(Palette.warnText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your hook runs ~\(DurationText.short(overrun))")
                        .cueFont(.subheadline, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                    Text("Aim for about 3s. See shorter openings.")
                        .cueFont(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .cueFont(.caption, weight: .semibold)
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
        let subtitle = tool.subtitle(idealRange: viewModel.preset.idealRange, platform: viewModel.script?.platform ?? .tiktok)
        let label = HStack(spacing: 12) {
            Group {
                if isRunning {
                    ProgressView().tint(Palette.accText)
                } else {
                    Image(systemName: tool.systemImage)
                        .font(.fixed(17, weight: .medium))
                        .foregroundStyle(Palette.accText)
                }
            }
            .frame(width: 34, height: 34)
            .background(Palette.accSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.label)
                    .cueFont(.body, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .cueFont(.footnote)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .cueFont(.caption, weight: .semibold)
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
                        // A target Apple Intelligence can't draft in says so under its name (the way Language & Region's menus do).
                        Button { Task { await viewModel.run(.translate, language: language) } } label: {
                            Text(verbatim: language.localizedName)
                            if let note = viewModel.draftingNote(for: language) { Text(note) }
                        }
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
        .disabled(viewModel.runningTool != nil)
        .accessibilityIdentifier("improve.tool.\(tool.rawValue)")
    }
}
