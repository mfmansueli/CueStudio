//
//  ScriptBriefView.swift
//  Cue Studio
//

import SwiftUI

/// Bullets in, structured script out.
struct ScriptBriefView: View {
    @Bindable var viewModel: GenerateScriptViewModel
    let type: ScriptType
    let onGenerate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text(type.briefTip)
                } icon: {
                    Image(systemName: "lightbulb").foregroundStyle(Palette.accText)
                }
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.88))
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.acc.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.acc.opacity(0.25), lineWidth: 0.5))

                Text("Structure")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(Palette.ink2)
                    .padding(EdgeInsets(top: 14, leading: 4, bottom: 0, trailing: 4))
                Text(type.structure.blocks.joined(separator: "  →  "))
                    .font(.footnote)
                    .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(type.briefFields) { field in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(field.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.ink2)
                                .padding(.horizontal, 4)
                            TextField(field.example, text: Binding(
                                get: { viewModel.binding(for: field) },
                                set: { viewModel.setValue($0, for: field) }
                            ))
                            .font(.body)
                            .tint(Palette.accText)
                            .padding(.horizontal, 14)
                            .frame(height: Metrics.hitTarget)
                            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                            .accessibilityIdentifier("generate.field.\(field.key)")
                        }
                    }
                }
                .padding(.top, 14)

                OptionChipRow(title: "Create for", options: Platform.primary, selection: $viewModel.platform, label: \.label, identifier: "generate.platform")
                    .padding(.top, 14)
                OptionChipRow(title: "Tone", options: viewModel.tones, selection: $viewModel.tone, label: \.label, identifier: "generate.tone")
                    .padding(.top, 14)

                if viewModel.isSerious {
                    if let note = type.briefNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(Palette.ink.opacity(0.8))
                            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.top, 14)
                    }
                } else {
                    VoiceToggleRow(summary: viewModel.voiceSummary)
                        .padding(.top, 14)
                }

                if let note = viewModel.modelNote {
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 14)
                }

                GenerateButton(isGenerating: viewModel.isGenerating, action: onGenerate)
                    .padding(.top, 18)
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(type.structure.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}
