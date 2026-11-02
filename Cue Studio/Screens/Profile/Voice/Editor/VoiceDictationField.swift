//
//  VoiceDictationField.swift
//  Cue Studio
//

import SwiftUI

/// A field the creator can type or speak into (the owner's item 9, 02/11/2026): the microphone fills it with what they say, in the language
/// their scripts are in, and they read it before tapping Save.
struct VoiceDictationField: View {
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages

    let placeholder: String
    var identifier = "voice.dictation"
    /// The text and whether it was said; returns whether it was kept (the field empties).
    let onSave: (String, Bool) -> Bool

    @State private var text = ""
    @State private var said = false
    @State private var isListening = false
    @State private var before = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 2) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .cueFont(.body)
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier(identifier)
                DictationButton(state: isListening ? dictation.state : .idle) { toggle() }
                    .accessibilityLabel(isListening ? Text("Stop dictation") : Text("Say it"))
                    .accessibilityHint(Text(verbatim: ""))
                    .accessibilityIdentifier("\(identifier).dictate")
            }
            .padding(.leading, 14)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if isListening, let notice = dictation.notice {
                DictationNoticeView(notice: notice)
            }
            if !trimmed.isEmpty, !isListening {
                Button("Save") {
                    if onSave(trimmed, said) {
                        text = ""
                        said = false
                    }
                }
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("\(identifier).save")
            }
        }
        .onChange(of: dictation.state) { _, state in
            if state == .idle { isListening = false }
        }
        .onDisappear { if isListening { dictation.cancel() } }
    }

    private func toggle() {
        if isListening {
            dictation.stop()
            return
        }
        guard dictation.state == .idle else { return }
        before = trimmed
        isListening = true
        said = true
        Haptics.selection()
        Task {
            await dictation.start(language: languages.dictationRequest(existingText: before)) { heard in
                text = before.isEmpty ? heard : before + " " + heard
            }
            if dictation.state == .idle { isListening = false }
        }
    }
}
