//
//  BrandFontsList.swift
//  Cue Studio
//

import SwiftUI

/// "Your fonts": the families the creator imported, each written in itself with its styles, Remove (videos that use it keep
/// it; Undo), and Import font. Only fonts the creator has the right to use; Cue keeps them on this iPhone, for Cue alone.
struct BrandFontsList: View {
    let viewModel: QuickEditViewModel

    private var brand: BrandViewModel { viewModel.brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your fonts")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
            ForEach(brand.offeredFonts) { family in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: family.name)
                            .font(CueStudioFont.chip(family.font, size: 17))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(family.summary)
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        brand.removeFont(family.name)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                            .foregroundStyle(Palette.ink2)
                            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(family.name)"))
                    .accessibilityIdentifier("edit.brand.removeFont.\(family.name)")
                }
                .accessibilityElement(children: .contain)
            }
            FontImportButton(viewModel: viewModel)
            Text("Import only fonts you’re allowed to use in videos. They stay on this iPhone, for Cue alone.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

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
