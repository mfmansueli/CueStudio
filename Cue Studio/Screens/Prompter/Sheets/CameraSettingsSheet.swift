//
//  CameraSettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// Camera and recording options for this recording session. Lens, frame, quality, microphone and
/// safe zones change for this take only (the usual ones are in Profile › Creator Setup); grid,
/// stabilization, countdown and the rest are saved as before.
struct CameraSettingsSheet: View {
    private enum Tab: Hashable { case camera, recording }

    @Environment(SessionSetupService.self) private var session
    @Environment(CameraManager.self) private var camera
    @Environment(AudioInputManager.self) private var audio
    /// Tallest the sheet may grow, so the script above it stays readable. `nil` lets it go full height.
    var maxHeight: CGFloat?

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .camera
    /// Whether this iPhone can find people in video; nil until checked.
    @State private var canFindPeople: Bool?

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
        @Bindable var session = session
        SectionHeading(text: String(localized: "Lens")).padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
        if camera.availableLenses.isEmpty {
            Text("Cameras appear here once the camera is running.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        } else {
            GroupedCard(background: Palette.surface2, radius: 22) {
                ForEach(camera.availableLenses) { lens in
                    checkRow(title: lens.label, detail: lens.detail, isSelected: session.camera.lens == lens) {
                        session.camera.lens = lens
                    }
                }
            }
        }

        SectionHeading(text: String(localized: "Frame")).padding(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
        HStack(spacing: 8) {
            ForEach(AspectRatio.allCases) { aspect in
                Button {
                    session.camera.aspect = aspect
                } label: {
                    SelectableCard(isSelected: session.camera.aspect == aspect) {
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
            segmentedRow(String(localized: "Resolution"), selection: $session.camera.resolution, options: VideoResolution.allCases) { $0.label }
            segmentedRow(String(localized: "Frame rate"), selection: $session.camera.frameRate, options: FrameRate.allCases) { $0.label }
            SettingToggleRow(title: String(localized: "Grid"), isOn: $session.camera.showsGrid, minHeight: 52)
            SettingToggleRow(title: String(localized: "Platform safe zones"), detail: String(localized: "Shows where app buttons and captions cover the frame"), isOn: $session.camera.showsSafeZones, minHeight: 52)
            SettingToggleRow(title: String(localized: "Stabilization"), isOn: $session.camera.stabilization, minHeight: 52)
        }
        .padding(.top, 10)
        setupNote
        backgroundSection
    }

    // MARK: - Background

    /// The background behind the creator for the next takes: shown live, saved with the take as a
    /// recipe, the recording untouched.
    @ViewBuilder
    private var backgroundSection: some View {
        let effect = camera.background
        SectionHeading(text: String(localized: "Background")).padding(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
        HStack(spacing: 6) {
            ForEach([BackgroundStyle.original, .blur, .color]) { style in
                let isOn = effect.style == style
                Button {
                    var changed = effect
                    changed.style = style
                    changed.cutout = .person
                    Task { await camera.setBackground(changed) }
                } label: {
                    FilterChip(label: style.label, isSelected: isOn, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(style != .original && canFindPeople == false)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("camera.background.\(style.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .disabled(camera.isRecording)
        if effect.style == .color {
            HStack(spacing: 10) {
                ForEach(OverlayColor.allCases) { color in
                    SwatchButton(color: color.color, isSelected: effect.color == color, accessibilityName: color.label) {
                        var changed = effect
                        changed.color = color
                        Task { await camera.setBackground(changed) }
                    }
                }
            }
            .padding(.top, 4)
        }
        Group {
            if canFindPeople == false {
                Text("This iPhone can’t find people in video, so the background can’t change here.")
                    .foregroundStyle(Palette.warn)
            } else if effect.isActive, !camera.showsBackgroundLive {
                Text("This camera can’t show the effect while recording. It’s added to the take after you record.")
                    .foregroundStyle(Palette.warn)
            }
            Text("Your recording stays as filmed. The effect is added to the take, and you can change it in Quick edit.")
                .foregroundStyle(Palette.ink2)
        }
        .font(.footnote)
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
        .task {
            if canFindPeople == nil { canFindPeople = await BackgroundSupport.canFindPeople() }
        }
    }

    // MARK: - Recording

    @ViewBuilder
    private var recordingTab: some View {
        @Bindable var session = session
        SectionHeading(text: String(localized: "Microphone")).padding(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
        GroupedCard(background: Palette.surface2, radius: 22) {
            checkRow(title: String(localized: "Automatic"), detail: String(localized: "Uses the connected mic, or the iPhone's"), isSelected: session.camera.microphoneID == nil) {
                selectMicrophone(nil)
            }
            ForEach(audio.inputs) { input in
                checkRow(title: input.name, detail: input.detail, isSelected: session.camera.microphoneID == input.id) {
                    selectMicrophone(input)
                }
            }
        }

        SectionHeading(text: String(localized: "Take")).padding(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
        GroupedCard(background: Palette.surface2, radius: 22) {
            segmentedRow(String(localized: "Countdown"), selection: $session.camera.countdown, options: Countdown.allCases) { $0.label }
            SettingToggleRow(title: String(localized: "Start scrolling with recording"), isOn: $session.camera.scrollsWithRecording, minHeight: 52)
            SettingToggleRow(title: String(localized: "Stop when script ends"), isOn: $session.camera.stopsWhenScriptEnds, minHeight: 52)
            segmentedRow(String(localized: "Format"), selection: $session.camera.codec, options: VideoCodec.allCases) { $0.label }
        }
        Text("HEVC keeps files small. Choose H.264 if you edit on older software.")
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
    }

    /// Where the usual setup lives, so a change here isn't mistaken for a new default.
    private var setupNote: some View {
        Text("Lens, frame, quality and mic change for this take. Your usual setup stays in Profile › Creator Setup.")
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
    }

    private func selectMicrophone(_ input: MicrophoneOption?) {
        var camera = session.camera
        camera.microphoneID = input?.id
        camera.microphoneName = input?.name
        session.camera = camera
        audio.select(input?.id)
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
    .environment(SessionSetupService(preferences: AppServices.preview.preferences))
    .previewEnvironment()
}
#endif
