//
//  BrandFontsList.swift
//  Cue Studio
//

import SwiftUI

/// "Your fonts": the families the creator imported, each written in itself with its styles, Remove (videos that use it keep
/// it; Undo), and Import font. Only fonts the creator has the right to use; Cue keeps them on this iPhone, for Cue alone.
/// Below them, once one came, the script libraries' families downloaded (`FontPackStore`), with what they take and Remove.
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
            downloaded
            Text("Import only fonts you’re allowed to use in videos. They stay on this iPhone, for Cue alone.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The script libraries' families on this iPhone; nothing when none came.
    @ViewBuilder
    private var downloaded: some View {
        let packs = brand.downloadedPacks
        if !packs.isEmpty {
            Text("Downloaded fonts")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 8)
            ForEach(packs, id: \.pack.id) { entry in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        let label = "\(entry.pack.script.sample) \(entry.pack.family)"
                        Text(verbatim: label)
                            .font(Font(TextFont.font(.pack(entry.pack.id), weight: entry.pack.weights.first ?? .regular, size: 17, text: label)))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(verbatim: "\(entry.pack.script.libraryTitle) · \(entry.bytes.formatted(.byteCount(style: .file)))")
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        brand.removePack(entry.pack)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                            .foregroundStyle(Palette.ink2)
                            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(entry.pack.family)"))
                    .accessibilityIdentifier("edit.brand.removeFontPack.\(entry.pack.id)")
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}
