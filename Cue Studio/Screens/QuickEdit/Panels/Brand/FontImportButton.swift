//
//  FontImportButton.swift
//  Cue Studio
//

import SwiftUI

/// "Import font": Files, for TTF and OTF files (several at once: a family's styles); `onImported` gets the first family that
/// came in, for the picker it sits under to pick it.
struct FontImportButton: View {
    let viewModel: QuickEditViewModel
    var onImported: ((TextOverlayFont) -> Void)?

    @State private var isPicking = false

    var body: some View {
        PanelButton(label: String(localized: "Import font"), systemImage: "square.and.arrow.down", identifier: "edit.importFont") {
            isPicking = true
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: BrandViewModel.fontTypes, allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { await viewModel.brand.importFonts(urls, then: onImported) }
        }
    }
}
