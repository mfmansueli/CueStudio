//
//  WritingImportCollectView.swift
//  Cue Studio
//

import SwiftUI

/// The first step of the import: paste or open texts the creator wrote, see what Cue has so far, say they are their own words, and read them.
struct WritingImportCollectView: View {
    @Bindable var model: WritingImportViewModel
    let onRead: () -> Void
    @State private var picksFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Bring scripts, captions or notes you wrote. Cue learns how you write from them, on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
            pasteBox
            if !model.sources.isEmpty { added }
            Toggle("I wrote these myself", isOn: $model.isOwn)
                .font(.subheadline)
                .tint(Palette.successText)
                .accessibilityIdentifier("import.own")
            Button(action: onRead) { Text("Read my writing") }
                .buttonStyle(.cuePrimary(.large))
                .disabled(!model.canRead)
                .accessibilityIdentifier("import.read")
            Text("Only a few sentences are kept, never the originals. Nothing leaves this iPhone.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
        .fileImporter(isPresented: $picksFiles, allowedContentTypes: WritingFileReader.contentTypes, allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { await model.addFiles(urls) }
        }
    }

    // MARK: - Pasting

    private var pasteBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(String(localized: "Paste your texts here. Put a line of --- between them."), text: $model.draft, axis: .vertical)
                .lineLimit(5...10)
                .padding(14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                .accessibilityIdentifier("import.field")
            if model.pasteWasEmpty {
                Text("Nothing Cue could read in that. Texts need a dozen words or more.")
                    .font(.footnote)
                    .foregroundStyle(Palette.warnText)
                    .accessibilityIdentifier("import.pasteEmpty")
            }
            // Two buttons side by side when they fit, one under the other in the languages whose words are longer.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    pasteButton
                    filesButton
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    pasteButton
                    filesButton
                }
            }
            Button { model.addDraft(source: String(localized: "Pasted")) } label: { Text("Add text") }
                .buttonStyle(.cueSecondary(.large))
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("import.add")
        }
    }

    private var pasteButton: some View {
        Button { model.draft = UIPasteboard.general.string ?? model.draft } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.cueSecondary(.compact, expands: false))
        .accessibilityIdentifier("import.paste")
    }

    private var filesButton: some View {
        Button { picksFiles = true } label: {
            Label("Choose files", systemImage: "doc.badge.plus")
        }
        .buttonStyle(.cueSecondary(.compact, expands: false))
        .accessibilityIdentifier("import.files")
    }

    // MARK: - What is there

    private var added: some View {
        VStack(alignment: .leading, spacing: 8) {
            VoiceFieldLabel(String(localized: "Texts: \(model.pieces.count) · Words: \(model.wordCount)"))
                .accessibilityIdentifier("import.count")
            ForEach(model.sources, id: \.name) { source in
                HStack(spacing: 10) {
                    Text("\(source.name.isEmpty ? String(localized: "Pasted") : source.name) · \(source.count)")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { model.remove(source: source.name) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.ink3)
                            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    }
                    .accessibilityLabel(Text("Remove"))
                    .accessibilityIdentifier("import.remove")
                }
                .padding(.leading, 14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if model.skippedFiles > 0 {
                Text("Some files had no text Cue could read.")
                    .font(.footnote)
                    .foregroundStyle(Palette.warnText)
            }
            if model.needsMoreForHabits {
                Text("Add at least 3 texts to find your phrases and how you open and close.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("import.needMore")
            }
        }
    }
}
