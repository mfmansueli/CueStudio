//
//  PromptTabView.swift
//  Cue Studio
//

import SwiftUI

/// Generate › Prompt: describe the video, pick the platform and length, and write.
struct PromptTabView: View {
    @Bindable var viewModel: GenerateScriptViewModel
    let onGenerate: () -> Void

    @FocusState private var isEditing: Bool

    private var showsExamples: Bool {
        viewModel.promptText.isEmpty && !viewModel.isGenerating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if viewModel.promptText.isEmpty {
                    Text("Describe your video… what it’s about, how long, who it’s for.")
                        .foregroundStyle(Palette.ink2)
                        .padding(EdgeInsets(top: 14 + 8, leading: 16 + 5, bottom: 0, trailing: 16))
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.promptText)
                    .focused($isEditing)
                    .scrollContentBackground(.hidden)
                    .tint(Palette.accText)
                    .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    .writingToolsBehavior(.limited)
                    .accessibilityLabel(Text("Describe your video"))
                    .accessibilityIdentifier("generate.promptField")
            }
            .font(.body)
            .frame(height: 112)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Ideas to start from, never content: they are shown only while the prompt is empty, and one
            // becomes the prompt only when it is tapped.
            if showsExamples {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(GenerateScriptViewModel.examples, id: \.self) { example in
                            Button { viewModel.useExample(example) } label: {
                                Text(example)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.ink.opacity(0.85))
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(Palette.overlayFill.opacity(0.6), in: Capsule())
                                    .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.14), lineWidth: 0.5))
                                    .frame(minHeight: Metrics.hitTarget)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -Metrics.gutter)
                .padding(.top, 4)
            }

            OptionChipRow(title: "Create for", options: Platform.primary, selection: $viewModel.platform, label: \.label, identifier: "generate.platform")
                .padding(.top, 10)
            OptionChipRow(title: "Length", options: ScriptLength.allCases, selection: $viewModel.length, label: \.label, identifier: "generate.length")
                .padding(.top, 14)

            VoiceToggleRow(summary: viewModel.voiceSummary)
                .padding(.top, 14)
            FactWarningNote(usesPrivateCloudCompute: viewModel.availability.privateCloud)
                .padding(.top, 12)

            if let reason = viewModel.availability.reason, !viewModel.canWriteFromPrompt {
                AIUnavailableNote(reason: reason)
                    .padding(.top, 12)
            }
            GenerateButton(
                isGenerating: viewModel.isGenerating,
                isEnabled: viewModel.canWriteFromPrompt && !viewModel.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onCancel: viewModel.cancelGeneration
            ) {
                isEditing = false
                onGenerate()
            }
            .padding(.top, 16)
        }
    }
}
