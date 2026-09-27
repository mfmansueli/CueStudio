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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text(type.briefTip)
                } icon: {
                    Image(systemName: "lightbulb").foregroundStyle(Palette.acc)
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
                    .foregroundStyle(Palette.ink.opacity(0.45))
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
                            .tint(Palette.acc)
                            .padding(.horizontal, 14)
                            .frame(height: Metrics.hitTarget)
                            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                            .accessibilityIdentifier("generate.field.\(field.key)")
                        }
                    }
                }
                .padding(.top, 14)

                chipRow(title: "Create for", options: Platform.primary, selection: $viewModel.platform) { $0.label }
                    .padding(.top, 14)
                chipRow(title: "Tone", options: viewModel.tones, selection: $viewModel.tone) { $0.label }
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
                    Toggle(isOn: $viewModel.usesPhrases) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use my phrases").font(.subheadline.weight(.semibold))
                            Text(viewModel.phrases.isEmpty
                                 ? String(localized: "Add phrases in Profile")
                                 : viewModel.phrases.map { "“\($0)”" }.joined(separator: " · "))
                                .font(.footnote)
                                .foregroundStyle(Palette.ink2)
                                .lineLimit(2)
                        }
                    }
                    .tint(Palette.success)
                    .disabled(viewModel.phrases.isEmpty)
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 14)
                }

                if let note = viewModel.modelNote {
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 14)
                }

                generateButton.padding(.top, 18)
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(type.structure.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var generateButton: some View {
        if viewModel.isGenerating {
            Text("Writing your script…")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.acc)
                .frame(maxWidth: .infinity, minHeight: Metrics.largeButtonHeight)
                .phaseAnimator(reduceMotion ? [0.2] : [0.14, 0.38]) { view, phase in
                    view.background(Palette.acc.opacity(phase), in: Capsule())
                } animation: { _ in .easeInOut(duration: 0.55) }
                .accessibilityLabel(Text("Writing your script"))
        } else {
            Button(action: onGenerate) {
                Label("Generate script", systemImage: "sparkles")
            }
            .buttonStyle(.cuePrimary(.large))
            .accessibilityIdentifier("generate.generateButton")
        }
    }

    private func chipRow<Option: Hashable>(
        title: LocalizedStringKey, options: [Option], selection: Binding<Option>, label: @escaping (Option) -> String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(width: 56, alignment: .leading)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        FilterChip(label: label(option), isSelected: selection.wrappedValue == option, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
