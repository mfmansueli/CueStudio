//
//  ImportScriptSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// Brings an existing script in: a file, a scan or photo of a printed brief (read on the device
/// with Vision), or the clipboard.
struct ImportScriptSheet: View {
    let onImported: (ImportedDocument) -> Void
    let onPaste: () -> Void

    @Environment(DocumentImportService.self) private var importer
    @Environment(TextRecognitionManager.self) private var recognizer
    @Environment(\.dismiss) private var dismiss
    @State private var showsFilePicker = false
    @State private var showsScanner = false
    @State private var showsPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isReading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(title: String(localized: "Import a script"), onClose: { dismiss() })
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    source("Files", systemImage: "folder", identifier: "import.files") { showsFilePicker = true }
                    if DocumentScannerView.isSupported {
                        source("Scan", systemImage: "doc.viewfinder", identifier: "import.scan") { showsScanner = true }
                    }
                    source("Photo", systemImage: "photo", identifier: "import.photo") { showsPhotoPicker = true }
                    source("Clipboard", systemImage: "doc.on.clipboard", identifier: "import.clipboard", action: onPaste)
                }
                if isReading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Palette.accText)
                        Text("Reading the text…").foregroundStyle(Palette.accText)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                Label {
                    Text("Writing in Google Docs, Notion or Pages? Export the script as .txt, .rtf or .pdf to Files — or copy the text and use Clipboard. A printed brief? Scan it or pick a photo.")
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
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
        .fileImporter(isPresented: $showsFilePicker, allowedContentTypes: importer.supportedTypes) { result in
            switch result {
            case .success(let url): importFile(at: url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .fullScreenCover(isPresented: $showsScanner) {
            DocumentScannerView(
                onScanned: { images in
                    showsScanner = false
                    recognize(images)
                },
                onCancel: { showsScanner = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await readPhotos(items) }
        }
        .alert("Couldn't import", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sources

    private func source(
        _ title: LocalizedStringKey, systemImage: String, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            sourceLabel(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .disabled(isReading)
        .accessibilityIdentifier(identifier)
    }

    private func sourceLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Palette.ink)
                .frame(width: 64, height: 64)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Reading

    private func importFile(at url: URL) {
        do {
            onImported(try importer.importDocument(at: url))
        } catch DocumentImportError.noText where url.pathExtension.lowercased() == "pdf" {
            // A scanned PDF has no text layer: read its pages like photos.
            recognize(importer.pageImages(ofPDFAt: url, maxPages: 10))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func readPhotos(_ items: [PhotosPickerItem]) async {
        var images: [CGImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data)?.uprightCGImage {
                images.append(image)
            }
        }
        photoItems = []
        recognize(images)
    }

    private func recognize(_ images: [CGImage]) {
        guard !images.isEmpty else {
            errorMessage = DocumentImportError.noText.localizedDescription
            return
        }
        isReading = true
        Task {
            defer { isReading = false }
            do {
                onImported(try await recognizer.recognizeText(in: images))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
