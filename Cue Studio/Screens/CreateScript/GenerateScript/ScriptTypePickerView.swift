//
//  ScriptTypePickerView.swift
//  Cue Studio
//

import SwiftUI

/// "What kind of video?" — the formats creators post most, each with its structure.
struct ScriptTypePickerView: View {
    let viewModel: GenerateScriptViewModel
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(
                    title: String(localized: "What kind of video?"),
                    subtitle: String(localized: "Pick a format. Cue builds the structure — you just fill in bullets."),
                    onClose: onClose
                )
                if let quota = viewModel.quotaLabel {
                    TagPill(text: quota)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(ScriptType.allCases) { type in
                        Button {
                            viewModel.choose(type)
                        } label: {
                            typeCard(type)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("generate.type.\(type.rawValue)")
                    }
                }
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private func typeCard(_ type: ScriptType) -> some View {
        let structure = type.structure
        return VStack(alignment: .leading, spacing: 3) {
            Text(structure.label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
            Text(type.summary).font(.footnote).foregroundStyle(Palette.ink2)
            Spacer(minLength: 8)
            Text(structure.blocks.joined(separator: " → "))
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.4))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(13)
        .background(structure.isSerious ? Palette.surfaceMuted : Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
        .overlay {
            if structure.isSerious {
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(0.18), lineWidth: 0.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
    }
}
