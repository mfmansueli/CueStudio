//
//  CreatorSetupView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Creator Setup: how the creator usually records ("Set it up once. Cue remembers how
/// you create."). Optional: a new creator records with Cue's defaults without ever opening it.
/// Platform recommendations appear when a recording starts and never change what's set here.
struct CreatorSetupView: View {
    @State private var viewModel: CreatorSetupViewModel
    @State private var showsMicrophones = false
    @State private var confirmsReset = false

    init(preferences: PreferencesService, microphones: MicrophoneListing, toast: ToastService) {
        _viewModel = State(initialValue: CreatorSetupViewModel(preferences: preferences, microphones: microphones, toast: toast))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                intro
                heading(String(localized: "Recording"))
                RecordingSetupSection(viewModel: viewModel) { showsMicrophones = true }
                heading(String(localized: "Teleprompter"))
                TeleprompterSetupSection(viewModel: viewModel)
                heading(String(localized: "Remote Control"))
                RemoteSetupSection()
                resetButton
            }
            .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .background(Palette.bg)
        .navigationTitle("Creator Setup")
        .task { viewModel.refreshInputs() }
        .sheet(isPresented: $showsMicrophones) {
            CreatorMicrophoneSheet(viewModel: viewModel)
        }
        .confirmationDialog("Reset Creator Setup?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset Creator Setup", role: .destructive) { viewModel.reset() }
                .accessibilityIdentifier("creatorSetup.confirmResetButton")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera, microphone, quality, format and teleprompter go back to Cue's defaults. Your scripts, takes and edits stay.")
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This is what you usually use.")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("Every recording starts from here. When a video is for a platform, Cue recommends its setup — you choose, and your setup stays the same.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                stops: [.init(color: Palette.accGlow, location: 0), .init(color: Palette.accGlowFaint, location: 0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func heading(_ text: String) -> some View {
        SectionHeading(text: text)
            .padding(EdgeInsets(top: 14, leading: 4, bottom: 0, trailing: 4))
    }

    private var resetButton: some View {
        Button("Reset Creator Setup") { confirmsReset = true }
            .buttonStyle(.cueDestructiveTinted())
            .padding(.top, 24)
            .accessibilityIdentifier("creatorSetup.resetButton")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CreatorSetupView(
            preferences: AppServices.preview.preferences,
            microphones: AppServices.preview.audio,
            toast: AppServices.preview.toast
        )
    }
    .previewEnvironment()
}
#endif
