//
//  NewScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// "New script": the prompt box first, then Write, Import, Themes and Formats. Over the camera
/// (attach mode) a blank page makes no sense, so Paste takes Write's place.
struct NewScriptSheet: View {
    enum Mode { case new, attach }

    let mode: Mode
    let onPrompt: () -> Void
    var onWrite: () -> Void = {}
    var onPaste: () -> Void = {}
    let onImport: () -> Void
    let onThemes: () -> Void
    let onFormats: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: String(localized: "New script"),
                subtitle: String(localized: "Start from an idea, a blank page or a document."),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            PromptCard(action: onPrompt)
                .accessibilityIdentifier("newScript.prompt")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                switch mode {
                case .new:
                    tile("Write", detail: "Blank page", systemImage: "pencil.line", identifier: "newScript.write", action: onWrite)
                case .attach:
                    tile("Paste", detail: "From clipboard", systemImage: "doc.on.clipboard", identifier: "newScript.paste", action: onPaste)
                }
                tile("Import", detail: "Files or clipboard", systemImage: "doc.text", identifier: "newScript.import", action: onImport)
                tile("Themes", detail: "Ideas for your niche", systemImage: "lightbulb", identifier: "newScript.themes", action: onThemes)
                tile("Formats", detail: "Ad, review, tutorial…", systemImage: "square.grid.2x2", identifier: "newScript.formats", action: onFormats)
            }
            .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
    }

    private func tile(
        _ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String,
        identifier: String, action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(14)
            .background(Palette.surface2, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        NewScriptSheet(mode: .new, onPrompt: {}, onWrite: {}, onImport: {}, onThemes: {}, onFormats: {})
    }
}
#endif
