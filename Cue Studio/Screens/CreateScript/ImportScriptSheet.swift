//
//  ImportScriptSheet.swift
//  Cue Studio
//

import AVFoundation
import PhotosUI
import SwiftUI

/// Import (v29 · I): Paste, Scan, Photo or File brings the text into an editable box; the creator fixes what the OCR
/// misread, and "Use this script" makes it a real script (it counts as Done: READY). A scan or a photo is read on the
/// iPhone with Vision. Without the camera's permission the Scan source says so and leads to Settings.
struct ImportScriptSheet: View {
    let onImported: (ImportedDocument) -> Void

    enum Source: String, CaseIterable, Identifiable {
        case paste, scan, photo, file
        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .paste: "Paste"
            case .scan: "Scan"
            case .photo: "Photo"
            case .file: "File"
            }
        }
    }

    @Environment(DocumentImportService.self) private var importer
    @Environment(TextRecognitionManager.self) private var recognizer
    @Environment(ToastService.self) private var toast
    @Environment(\.openURL) private var openURL
    @State private var source: Source = .paste
    @State private var text = ""
    @State private var kind = ""
    @State private var fileName: String?
    @State private var showsFilePicker = false
    @State private var showsScanner = false
    @State private var showsPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isReading = false
    @State private var cameraIsOff = false
    @State private var errorMessage: String?
    @FocusState private var isEditing: Bool

    private var canUse: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isReading }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.blockGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import")
                        .font(CueStudioFont.hud).textCase(.uppercase).tracking(1.2)
                        .foregroundStyle(Palette.accText)
                    Text("Bring a script in")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                sourcePicker
                if cameraIsOff { cameraCard }
                editor
                if isReading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Palette.accText)
                        Text("Reading the text…").foregroundStyle(Palette.accText)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                Button(action: use) { Text("Use this script") }
                    .buttonStyle(.cuePrimary(.large))
                    .disabled(!canUse)
                    .accessibilityIdentifier("import.use")
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 28, trailing: Metrics.gutter))
        }
        .scrollDismissesKeyboard(.interactively)
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
                    recognize(images, as: String(localized: "Scan"))
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
        .accessibilityIdentifier("import.sheet")
    }

    // MARK: - Pieces

    /// Paste · Scan · Photo · File: choosing one brings the text in (Paste reads the clipboard at once).
    private var sourcePicker: some View {
        HStack(spacing: 4) {
            ForEach(Source.allCases) { option in
                Button { choose(option) } label: {
                    Text(option.title)
                        .font(.system(size: 15, weight: source == option ? .semibold : .medium))
                        .foregroundStyle(source == option ? Palette.chipOnInk : Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(source == option ? Palette.chipOn : .clear, in: Capsule())
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isReading || (option == .scan && !DocumentScannerView.isSupported))
                .accessibilityAddTraits(source == option ? [.isSelected] : [])
                .accessibilityIdentifier("import.source.\(option.rawValue)")
            }
        }
        .padding(3)
        .background(Palette.fill, in: Capsule())
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($isEditing)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
                .foregroundStyle(Palette.ink)
                .tint(Palette.accText)
                .padding(10)
                .accessibilityLabel(Text("Script text"))
                .accessibilityIdentifier("import.editor")
            if text.isEmpty {
                Text("Paste, scan or pick a script. You can fix it before you use it.")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.inkHint)
                    .padding(.horizontal, 15).padding(.vertical, 18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 220)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
    }

    /// Scan without the camera's permission: why, and the way to Settings.
    private var cameraCard: some View {
        HStack(spacing: 12) {
            Text("Allow camera in Settings")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.accText)
            .frame(minHeight: Metrics.hitTarget)
            .accessibilityIdentifier("import.openSettings")
        }
        .padding(.horizontal, 14)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .accessibilityIdentifier("import.cameraOff")
    }

    // MARK: - Sources

    private func choose(_ option: Source) {
        source = option
        cameraIsOff = false
        switch option {
        case .paste: pasteFromClipboard()
        case .scan: startScan()
        case .photo: showsPhotoPicker = true
        case .file: showsFilePicker = true
        }
    }

    private func pasteFromClipboard() {
        guard let pasted = importer.clipboardText() else {
            toast.show(String(localized: "Copy your script first"))
            isEditing = true
            return
        }
        text = pasted
        kind = String(localized: "Pasted text")
        fileName = nil
    }

    private func startScan() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            cameraIsOff = true
        } else {
            showsScanner = true
        }
    }

    private func importFile(at url: URL) {
        do {
            take(try importer.importDocument(at: url))
        } catch DocumentImportError.noText where url.pathExtension.lowercased() == "pdf" {
            // A scanned PDF has no text layer: read its pages like photos.
            recognize(importer.pageImages(ofPDFAt: url, maxPages: 10), as: "PDF")
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
        recognize(images, as: String(localized: "Photo"))
    }

    private func recognize(_ images: [CGImage], as kind: String) {
        guard !images.isEmpty else {
            errorMessage = DocumentImportError.noText.localizedDescription
            return
        }
        isReading = true
        Task {
            defer { isReading = false }
            do {
                take(try await recognizer.recognizeText(in: images))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// The text read goes into the box to review.
    private func take(_ document: ImportedDocument) {
        text = document.text
        kind = document.kind
        fileName = document.title
        isEditing = false
    }

    /// "Use this script": the box's text, as the creator left it.
    private func use() {
        let title = fileName ?? ScriptTextNormalizer.suggestedTitle(fileName: nil, text: text)
        onImported(ImportedDocument(title: title, text: text, kind: kind.isEmpty ? String(localized: "Pasted text") : kind))
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        ImportScriptSheet(onImported: { _ in })
    }
    .previewEnvironment()
}
#endif
