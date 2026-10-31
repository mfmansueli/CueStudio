//
//  TextToSpeechSheet.swift
//  Cue Studio
//

import SwiftUI

/// Text to speech (Audio bar, or Edit text on a spoken voice-over): the text to say, "Use the script" when the take has one, the
/// language and voice (only those on this iPhone; a note says where better ones are downloaded when it has only compact ones),
/// the speed, ▶ to hear the first sentence, and Add at the playhead (Replace in place for a spoken voice-over), with Cancel
/// while it's made. The voice-over then trims, moves and deletes like a recorded one.
struct TextToSpeechSheet: View {
    let viewModel: QuickEditViewModel
    @State private var speech: TextToSpeechViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWriting: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let speeds: [Double] = [0.75, 1, 1.25, 1.5]
    /// "Voice" as the one that speaks: its own key, apart from the writing voice of My Cue Voice.
    private static var voiceLabel: String {
        String(localized: "tts.voice", defaultValue: "Voice", comment: "Text to speech sheet: the system voice that will speak the text (a narrator), not a writing style.")
    }

    init(viewModel: QuickEditViewModel) {
        self.viewModel = viewModel
        _speech = State(initialValue: viewModel.audio.makeTextToSpeech())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(
                title: speech.replacing == nil ? String(localized: "Text to speech") : String(localized: "Edit spoken text"),
                subtitle: String(localized: "Spoken by a voice on this iPhone, offline")
            )
            .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    textField
                    voicePicker
                    PanelSegmented(
                        label: String(localized: "Speed"),
                        options: Self.speeds.map { PanelOption($0, SpeedScale.label(forMultiple: $0), key: "\($0)") },
                        selection: speech.speed, identifier: "tts.speed"
                    ) { speech.speed = $0 }
                    .disabled(speech.phase == .making)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .onDisappear { speech.cancel() }
        .interactiveDismissDisabled(speech.phase == .making)
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Text

    private var textField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(String(localized: "Type what the voice will say"), text: $speech.text, axis: .vertical)
                .lineLimit(5...10)
                .focused($isWriting)
                .padding(14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                .disabled(speech.phase == .making)
                .accessibilityIdentifier("tts.text")
            HStack {
                if speech.script != nil {
                    Button {
                        speech.useScript()
                    } label: {
                        Label(String(localized: "Use the script"), systemImage: "text.alignleft")
                            .font(.system(.footnote, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accText)
                    .frame(minHeight: Metrics.hitTarget)
                    .disabled(speech.phase == .making)
                    .accessibilityIdentifier("tts.useScript")
                }
                Spacer()
                Text(speech.countLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
        }
    }

    // MARK: - Voice

    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: Self.voiceLabel)
            Picker(String(localized: "Language"), selection: $speech.language) {
                ForEach(speech.languages, id: \.self) { language in
                    Text(TextToSpeechViewModel.name(of: language)).tag(language)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink)
            .accessibilityIdentifier("tts.language")
            if speech.voices.isEmpty {
                Text("No voice for this language on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(Palette.warnText)
            } else {
                Picker(Self.voiceLabel, selection: $speech.voiceID) {
                    ForEach(speech.voices) { voice in
                        Text(voice.title).tag(Optional(voice.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.ink)
                .accessibilityIdentifier("tts.voice")
            }
            if speech.hasOnlyCompactVoices {
                PanelNote(text: String(localized: "For a more natural voice, download an Enhanced or Premium one in Settings › Accessibility › Spoken Content › Voices."), teaches: true)
            }
        }
        .disabled(speech.phase == .making)
    }

    // MARK: - Hear, add, cancel

    private var footer: some View {
        VStack(spacing: 8) {
            if let problem = speech.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Palette.warnText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("tts.problem")
            }
            if speech.phase == .making {
                HStack(spacing: 12) {
                    ProgressView().tint(Palette.ink)
                    Text("Making the voice-over…")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    PanelButton(label: String(localized: "Cancel"), isCompact: true, identifier: "tts.cancel") { speech.cancel() }
                }
            } else {
                // The editor's own pills: the system's bordered button draws its words in the system blue (3.7:1 on its fill).
                // Side by side; one above the other at the accessibility text sizes, so "Hear" is never split.
                let previewing = speech.isPreviewPlaying || speech.phase == .previewing
                ReflowStack(spacing: 10) {
                    PanelButton(
                        label: previewing ? String(localized: "Stop") : String(localized: "Hear"),
                        systemImage: previewing ? "stop.fill" : "play.fill",
                        isEnabled: !speech.isEmpty && speech.voiceID != nil, identifier: "tts.preview"
                    ) {
                        isWriting = false
                        speech.togglePreview()
                    }
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 150)
                    PanelButton(
                        label: speech.replacing == nil ? String(localized: "Add") : String(localized: "Replace"), isPrimary: true,
                        isEnabled: speech.canMake, identifier: "tts.add"
                    ) {
                        isWriting = false
                        speech.make { narration, fileName, duration in
                            viewModel.audio.addSpoken(narration, fileName: fileName, duration: duration)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
