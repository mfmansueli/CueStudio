//
//  ThemesTabView.swift
//  Cue Studio
//

import SwiftUI

/// Generate › Themes: six ideas for the creator's niche. "Use" moves one into the prompt box.
struct ThemesTabView: View {
    let viewModel: GenerateScriptViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("For your niche · \(Text(viewModel.themeNiches).foregroundStyle(Palette.ink))")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                Spacer()
                Button {
                    Task { await viewModel.loadNewIdeas() }
                } label: {
                    HStack(spacing: 5) {
                        if viewModel.isLoadingThemes {
                            ProgressView().controlSize(.mini).tint(Palette.acc)
                        } else {
                            Image(systemName: "sparkles").font(.caption.weight(.bold))
                        }
                        Text("New ideas")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.acc)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoadingThemes)
                .accessibilityIdentifier("generate.newIdeas")
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)

            GroupedCard(background: Palette.surface2, radius: 22, dividerInset: 16) {
                ForEach(viewModel.themes) { idea in
                    Button { viewModel.useTheme(idea) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(idea.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                                Text(idea.meta)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Use")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.acc)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(Palette.accSoft, in: Capsule())
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("generate.theme.\(idea.id)")
                }
            }
            Text("Ideas come from your Creator Voice niche. Tap one to fine-tune it in Prompt.")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
    }
}
