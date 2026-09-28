//
//  FormatsTabView.swift
//  Cue Studio
//

import SwiftUI

/// Generate › Formats: the formats creators post most, each with its structure. Sponsored ad is Pro.
struct FormatsTabView: View {
    let viewModel: GenerateScriptViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a format. Cue builds the structure — you fill in bullets.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
                .padding(.top, 6)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ScriptType.allCases) { type in
                    Button {
                        viewModel.choose(type)
                    } label: {
                        card(type)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("generate.type.\(type.rawValue)")
                }
            }
        }
    }

    private func card(_ type: ScriptType) -> some View {
        let structure = type.structure
        let shape = RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 3) {
            Text(structure.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .padding(.trailing, viewModel.isLocked(type) ? 34 : 0)
            Text(type.summary).font(.footnote).foregroundStyle(Palette.ink2)
            Spacer(minLength: 8)
            Text(structure.blocks.joined(separator: " → "))
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.4))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(13)
        .background(structure.isSerious ? Palette.surfaceMuted : Palette.surface2, in: shape)
        .overlay {
            if structure.isSerious {
                shape.strokeBorder(Palette.ink.opacity(0.18), lineWidth: 0.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isLocked(type) {
                ProBadge().padding(10)
            }
        }
        .contentShape(shape)
    }
}
