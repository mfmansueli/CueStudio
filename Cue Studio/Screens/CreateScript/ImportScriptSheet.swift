//
//  ImportScriptSheet.swift
//  Cue Studio
//

import SwiftUI

/// Brings an existing script in from Files or the clipboard.
struct ImportScriptSheet: View {
    let onImported: (ImportedDocument) -> Void
    let onPaste: () -> Void

    @Environment(DocumentImportService.self) private var importer
    @Environment(\.dismiss) private var dismiss
    @State private var showsFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: String(localized: "Import a script"), onClose: { dismiss() })
                HStack(spacing: 10) {
                    source("Files", detail: "Documents, PDFs, exports", systemImage: "folder", identifier: "import.files") {
                        showsFilePicker = true
                    }
                    source("Clipboard", detail: "Paste copied text", systemImage: "doc.on.clipboard", identifier: "import.clipboard", action: onPaste)
                }
                Label {
                    Text("Writing in Google Docs, Notion or Pages? Export the script as .txt, .rtf or .pdf to Files — or copy the text and use Clipboard.")
                } icon: {
                    Image(systemName: "lightbulb")
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text("Supports .txt, .md, .rtf, .html, .pdf and .fountain")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity)
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.medium])
        .presentationBackground(Palette.surface)
        .fileImporter(isPresented: $showsFilePicker, allowedContentTypes: importer.supportedTypes) { result in
            switch result {
            case .success(let url):
                do {
                    onImported(try importer.importDocument(at: url))
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Couldn't import", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func source(
        _ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String,
        identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(detail).font(.footnote).foregroundStyle(Palette.ink2)
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        ImportScriptSheet(onImported: { _ in }, onPaste: {})
    }
    .previewEnvironment()
}
#endif
