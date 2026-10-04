//
//  SettingsRecordingView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Recording: camera, microphone, quality and the default format.
struct SettingsRecordingView: View {
    @State private var viewModel: CreatorSetupViewModel
    @State private var showsMicrophones = false

    init(preferences: PreferencesService, microphones: MicrophoneListing, toast: ToastService) {
        _viewModel = State(initialValue: CreatorSetupViewModel(preferences: preferences, microphones: microphones, toast: toast))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(text: String(localized: "Camera & format"))
                    .padding(.horizontal, 4)
                RecordingSetupSection(viewModel: viewModel) { showsMicrophones = true }
                Text("Lens, mic, quality and format can still change for one take while recording.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(EdgeInsets(top: 6, leading: 4, bottom: 0, trailing: 4))
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .background(Palette.bg)
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.refreshInputs() }
        .sheet(isPresented: $showsMicrophones) { CreatorMicrophoneSheet(viewModel: viewModel) }
    }
}
