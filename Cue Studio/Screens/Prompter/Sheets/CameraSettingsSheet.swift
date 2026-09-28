//
//  CameraSettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// Camera and recording options.
struct CameraSettingsSheet: View {
    private enum Tab: Hashable { case camera, recording }

    @Environment(PreferencesService.self) private var preferences
    @Environment(CameraManager.self) private var camera
    @Environment(AudioInputManager.self) private var audio
    /// Tallest the sheet may grow, so the script above it stays readable. `nil` lets it go full height.
    var maxHeight: CGFloat?

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .camera

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Settings", selection: $tab) {
                    Text("Camera").tag(Tab.camera)
                    Text("Recording").tag(Tab.recording)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.cuePrimary(.compact, expands: false))
                    .accessibilityIdentifier("camera.doneButton")
            }
            .padding(EdgeInsets(top: 18, leading: 16, bottom: 10, trailing: 16))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch tab {
                    case .camera: cameraTab
                    case .recording: recordingTab
                    }
                }
                .padding(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
            }
        }
        .presentationDetents(detents)
        .presentationBackground(Palette.surface)
        .presentationBackgroundInteraction(maxHeight.map { .enabled(upThrough: .height($0)) } ?? .automatic)
        .onAppear { audio.refreshInputs() }
    }

    private var detents: Set<PresentationDetent> {
        maxHeight.map { [.height($0)] } ?? [.fraction(0.75), .large]
    }

    // MARK: - Camera

    @ViewBuilder
    private var cameraTab: some View {
        @Bindable var preferences = preferences
        SectionHeading(text: String(localized: "Lens")).padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
        if camera.availableLenses.isEmpty {
            Text("Cameras appear here once the camera is running.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        } else {
            GroupedCard(background: Palette.surface2, radius: 22) {
                ForEach(camera.availableLenses) { lens in
                    checkRow(title: lens.label, detail: lens.detail, isSelected: preferences.camera.lens == lens) {
                        preferences.camera.lens = lens
                    }
                }
            }
        }

        SectionHeading(text: String(localized: "Frame")).padding(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
        HStack(spacing: 8) {
            ForEach(AspectRatio.allCases) { aspect in
                Button {
                    preferences.camera.aspect = aspect
                } label: {
                    SelectableCard(isSelected: preferences.camera.aspect == aspect) {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.white, lineWidth: 2)
                                .frame(width: 26 * min(1, aspect.widthOverHeight), height: 26 * min(1, 1 / aspect.widthOverHeight))
                            Text(aspect.label).font(.footnote.weight(.semibold))
                        }
                        .frame(height: 78)
                    }
                }
                .buttonStyle(.plain)
            }
        }

        GroupedCard(background: Palette.surface2, radius: 22) {
            segmentedRow(String(localized: "Resolution"), selection: $preferences.camera.resolution, options: VideoResolution.allCases) { $0.label }
            segmentedRow(String(localized: "Frame rate"), selection: $preferences.camera.frameRate, options: FrameRate.allCases) { $0.label }
            SettingToggleRow(title: String(localized: "Grid"), isOn: $preferences.camera.showsGrid, minHeight: 52)
            SettingToggleRow(title: String(localized: "Platform safe zones"), detail: String(localized: "Shows where app buttons and captions cover the frame"), isOn: $preferences.camera.showsSafeZones, minHeight: 52)
            SettingToggleRow(title: String(localized: "Stabilization"), isOn: $preferences.camera.stabilization, minHeight: 52)
        }
        .padding(.top, 10)
    }

    // MARK: - Recording

    @ViewBuilder
    private var recordingTab: some View {
        @Bindable var preferences = preferences
        SectionHeading(text: String(localized: "Microphone")).padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
        GroupedCard(background: Palette.surface2, radius: 22) {
            checkRow(title: String(localized: "Automatic"), detail: String(localized: "Uses the connected mic, or the iPhone's"), isSelected: preferences.camera.microphoneID == nil) {
                selectMicrophone(nil)
            }
            ForEach(audio.inputs) { input in
                checkRow(title: input.name, detail: input.detail, isSelected: preferences.camera.microphoneID == input.id) {
                    selectMicrophone(input.id)
                }
            }
        }

        SectionHeading(text: String(localized: "Take")).padding(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
        GroupedCard(background: Palette.surface2, radius: 22) {
            segmentedRow(String(localized: "Countdown"), selection: $preferences.camera.countdown, options: Countdown.allCases) { $0.label }
            SettingToggleRow(title: String(localized: "Start scrolling with recording"), isOn: $preferences.camera.scrollsWithRecording, minHeight: 52)
            SettingToggleRow(title: String(localized: "Stop when script ends"), isOn: $preferences.camera.stopsWhenScriptEnds, minHeight: 52)
            segmentedRow(String(localized: "Format"), selection: $preferences.camera.codec, options: VideoCodec.allCases) { $0.label }
        }
        Text("HEVC keeps files small. Choose H.264 if you edit on older software.")
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
    }

    private func selectMicrophone(_ id: String?) {
        preferences.camera.microphoneID = id
        audio.select(id)
    }

    // MARK: - Rows

    private func checkRow(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Palette.acc)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func segmentedRow<Option: Hashable & Identifiable>(
        _ title: String, selection: Binding<Option>, options: [Option], label: @escaping (Option) -> String
    ) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Picker(title, selection: selection) {
                ForEach(options) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 16)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        CameraSettingsSheet()
    }
    .previewEnvironment()
}
#endif
