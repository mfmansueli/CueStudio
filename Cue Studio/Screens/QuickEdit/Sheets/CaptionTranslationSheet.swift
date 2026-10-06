//
//  CaptionTranslationSheet.swift
//  Cue Studio
//

import SwiftUI

/// Captions in another language: pick it, translate on the iPhone (the system asks before
/// downloading a language), or write it by hand; read and correct each line under its original;
/// see which lines are outdated since the original changed; and choose what shows and exports:
/// the original, the translation, or both.
struct CaptionTranslationSheet: View {
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var target: CueLanguage?
    @State private var confirmsReplacing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Translate to", selection: $target) {
                        Text("Choose").tag(CueLanguage?.none)
                        ForEach(viewModel.translationTargets) { language in
                            Text(verbatim: language.nativeName).tag(Optional(language))
                        }
                    }
                    .accessibilityIdentifier("translation.language")
                    if let message = viewModel.translationState.message {
                        HStack(spacing: 10) {
                            if viewModel.translationState.isWorking { ProgressView().controlSize(.small) }
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Palette.ink2)
                                .accessibilityIdentifier("translation.status")
                        }
                    }
                    if let target {
                        actions(target)
                    }
                } footer: {
                    Text("Translated on your iPhone with Apple’s Translation. Nothing is sent anywhere.")
                }
                if let target, let translation = viewModel.translation(target) {
                    Section("Show and export") {
                        Picker("Show", selection: Binding(
                            get: { viewModel.edit.captionDisplay },
                            set: { viewModel.setCaptionDisplay($0) }
                        )) {
                            Text("Original").tag(CaptionDisplay.original)
                            Text(verbatim: target.nativeName).tag(CaptionDisplay.translation(target))
                            Text("Both").tag(CaptionDisplay.bilingual(target))
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("translation.display")
                    }
                    lines(translation)
                }
            }
            .navigationTitle("Translate captions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("translation.doneButton")
                }
            }
            .confirmationDialog("Translate your corrected lines again?", isPresented: $confirmsReplacing, titleVisibility: .visible) {
                Button("Keep my corrections") { start(replacingRevised: false) }
                Button("Translate them again", role: .destructive) { start(replacingRevised: true) }
            }
        }
        .onAppear {
            target = target ?? viewModel.edit.captionDisplay.language ?? viewModel.edit.captionTranslations.first?.language
        }
        .presentationDetents([.medium, .large])
        .cueSheetSurface()
    }

    // MARK: - Sections

    @ViewBuilder
    private func actions(_ target: CueLanguage) -> some View {
        let existing = viewModel.translation(target)
        Button(existing == nil ? String(localized: "Translate") : String(localized: "Translate again")) {
            if existing?.lines.contains(where: \.isRevised) == true {
                confirmsReplacing = true
            } else {
                start(replacingRevised: false)
            }
        }
        .disabled(viewModel.translationState.isWorking || viewModel.edit.captions.isEmpty)
        .accessibilityIdentifier("translation.translateButton")
        if existing == nil {
            Button("Write it myself") { viewModel.writeTranslation(target) }
                .accessibilityIdentifier("translation.writeButton")
        } else {
            Button("Delete this translation", role: .destructive) { viewModel.deleteTranslation(target) }
                .accessibilityIdentifier("translation.deleteButton")
        }
    }

    private func lines(_ translation: CaptionTranslation) -> some View {
        let outdated = Set(translation.outdatedLines(against: viewModel.edit.captions).map(\.id))
        let originals = Dictionary(viewModel.edit.captions.map { ($0.id, $0.text) }) { first, _ in first }
        return Section {
            ForEach(translation.lines) { line in
                TranslatedLineRow(
                    original: line.cueIDs.compactMap { originals[$0] }.joined(separator: " "),
                    text: line.text,
                    isOutdated: outdated.contains(line.id),
                    onCommit: { viewModel.setTranslatedText(translation.language, line: line.id, $0) },
                    onKeep: { viewModel.markTranslationCurrent(translation.language, line: line.id) }
                )
            }
        } header: {
            Text("Lines")
        } footer: {
            if !outdated.isEmpty {
                Text("\(outdated.count) lines changed in the original since they were translated.")
            }
        }
    }

    private func start(replacingRevised: Bool) {
        guard let target else { return }
        Task { await viewModel.translateCaptions(to: target, replacingRevised: replacingRevised) }
    }
}
