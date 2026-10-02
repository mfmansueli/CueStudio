//
//  OptionsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Script options: where it's for and what kind of script it is (each opens its sheet), whether
/// cues show while recording, how big the text is while writing, and Discard changes.
struct OptionsPanel: View {
    @Bindable var viewModel: ScriptDetailViewModel
    @Binding var textSize: ScriptTextSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Script options")
                .font(.subheadline.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            GroupedCard(background: Palette.surface2, radius: 14, dividerInset: 14) {
                if let script = viewModel.script {
                    ScriptOptionRow(title: String(localized: "Create for"), identifier: "editor.option.destination") {
                        viewModel.sheet = .destination
                    } value: {
                        HStack(spacing: 6) {
                            ColorDot(color: script.platform.tint, size: 7)
                            Text(script.platform.destinationName)
                        }
                    }
                    ScriptOptionRow(title: String(localized: "Script type"), identifier: "editor.option.type") {
                        viewModel.sheet = .scriptType
                    } value: {
                        Text(viewModel.structure.label)
                    }
                }
                Toggle("Show cues while recording", isOn: $viewModel.showsCues)
                    .font(.subheadline)
                    .tint(Palette.successText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("editor.option.cues")
                HStack(spacing: 12) {
                    Text("Text size").font(.subheadline)
                    Spacer(minLength: 8)
                    sizePicker
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
            }
            Button(role: .destructive) {
                viewModel.discardChanges()
            } label: {
                Text("Discard changes")
                    .font(.subheadline)
                    .foregroundStyle(Palette.dangerText)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.discardButton")
        }
        .accessibilityIdentifier("editor.panel.options")
    }

    /// Three "A"s, each at the size it makes the text.
    private var sizePicker: some View {
        HStack(spacing: 2) {
            ForEach(ScriptTextSize.allCases) { size in
                Button {
                    textSize = size
                } label: {
                    Text("A")
                        .font(.system(size: size == .small ? 14 : size == .medium ? 17 : 20, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 30)
                        .background(textSize == size ? Palette.surface3 : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(size.label))
                .accessibilityAddTraits(textSize == size ? .isSelected : [])
                .accessibilityIdentifier("editor.textSize.\(size.rawValue)")
            }
        }
        .padding(2)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
