//
//  SettingsPrompterView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter: a still preview that stays on top, Selfie | Studio beside it, and section
/// chips that take the creator to the rows below (Reading, Text, Line, Window, Safe zones).
struct SettingsPrompterView: View {
    @State private var viewModel: CreatorSetupViewModel
    @State private var isStudio = false

    init(preferences: PreferencesService, microphones: MicrophoneListing, toast: ToastService) {
        _viewModel = State(initialValue: CreatorSetupViewModel(preferences: preferences, microphones: microphones, toast: toast))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    PrompterOrbControls(viewModel: viewModel)
                        .id(PrompterSettingsSection.reading)
                    SectionHeading(text: String(localized: "More options"))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    TeleprompterSetupSection(viewModel: viewModel)
                }
                .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
            }
            .safeAreaInset(edge: .top, spacing: 0) { header(proxy) }
        }
        .background(Palette.bg)
        .navigationTitle("Prompter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                TeleprompterPreview(
                    textSize: viewModel.textSize, showsReadingLine: viewModel.showsReadingLine,
                    isMirrored: viewModel.isMirrored, isStudio: isStudio
                )
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Mode", selection: $isStudio) {
                        Text("Selfie").tag(false)
                        Text("Studio").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.prompterMode")
                    Text(isStudio ? "Full-screen text, no camera." : "Text over your camera, right under the lens.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                    Text("Shows proportions on your screen — not the final look.")
                        .font(.caption)
                        .foregroundStyle(Palette.ink3)
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PrompterSettingsSection.allCases) { section in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(section, anchor: .top) }
                        } label: {
                            FilterChip(label: section.label, isSelected: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.prompterChip.\(section.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 10, trailing: Metrics.gutter))
        .background(Palette.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
    }
}
