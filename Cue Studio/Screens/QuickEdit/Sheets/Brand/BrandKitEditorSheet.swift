//
//  BrandKitEditorSheet.swift
//  Cue Studio
//

import SwiftUI

/// A brand kit, made or changed: its name; its colors (up to six, any color: the palette's or the brand's exact one); its
/// title and caption fonts (the imported ones first, and Import font); its logo (one of the library's pictures) and corner;
/// and which of the creator's own styles it keeps: this video's, or one they saved, for texts, captions and the cover.
/// Nothing is saved until Save; saving never changes a video.
struct BrandKitEditorSheet: View {
    let viewModel: QuickEditViewModel
    @State var kit: BrandKit

    @Environment(\.dismiss) private var dismiss
    private var brand: BrandViewModel { viewModel.brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: brand.kits.kit(kit.id) == nil ? String(localized: "New brand kit") : String(localized: "Edit brand kit"))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Kit name", text: $kit.name)
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: Metrics.hitTarget)
                        .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                        .accessibilityIdentifier("edit.brand.kitName")
                    colors
                    fonts
                    logo
                    styles
                }
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            PanelButton(label: String(localized: "Save kit"), isPrimary: true, identifier: "edit.brand.saveKit") {
                brand.saveKit(kit)
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear { brand.kitBeingEdited = nil }
    }

    // MARK: - Colors

    private var colors: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: String(localized: "Colors"), detail: "\(kit.colors.count)/\(BrandKit.maximumColors)")
            HStack(spacing: 4) {
                ForEach(kit.colors) { color in
                    Button {
                        kit.colors.removeAll { $0 == color }
                    } label: {
                        Circle().fill(color.color).frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(Palette.ink3, lineWidth: 1))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "minus.circle.fill").font(.caption).foregroundStyle(Palette.ink, Palette.surface)
                            }
                            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove \(color.label)"))
                }
                if kit.colors.count < BrandKit.maximumColors {
                    CustomColorWell(selection: nil, diameter: 30, identifier: "edit.brand.addColor") { color in
                        if !kit.colors.contains(color), kit.colors.count < BrandKit.maximumColors { kit.colors.append(color) }
                    }
                }
            }
            if kit.colors.count < BrandKit.maximumColors {
                PanelSwatches(label: String(localized: "Add from the palette"), colors: OverlayColor.palette, selection: nil, identifier: "edit.brand.palette") { color in
                    if !kit.colors.contains(color), kit.colors.count < BrandKit.maximumColors { kit.colors.append(color) }
                }
            }
        }
    }

    // MARK: - Fonts

    private var fonts: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: String(localized: "Titles font"), detail: kit.titleFont?.label)
            fontChips(selection: kit.titleFont, identifier: "edit.brand.titleFont") { kit.titleFont = $0 }
            PanelRowLabel(label: String(localized: "Captions font"), detail: kit.captionFont?.label)
            fontChips(selection: kit.captionFont, identifier: "edit.brand.captionFont") { kit.captionFont = $0 }
            FontImportButton(viewModel: viewModel)
        }
    }

    private func fontChips(selection: TextOverlayFont?, identifier: String, onSelect: @escaping (TextOverlayFont?) -> Void) -> some View {
        PanelChips(
            options: [PanelOption(TextOverlayFont?.none, String(localized: "None"), key: "none")]
                + TextOverlayFont.pickerFonts(including: selection).map { PanelOption(Optional($0), $0.label, key: $0.rawValue) },
            selection: selection,
            font: { face, size in face.map { CueStudioFont.chip($0, size: size) } ?? .system(size: size, weight: .semibold) },
            identifier: identifier, onSelect: onSelect
        )
    }

    // MARK: - Logo

    private var logo: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: String(localized: "Logo"), detail: kit.logo?.name)
            let pictures = brand.library.assets(in: .all).filter { $0.kind != .video }
            if pictures.isEmpty {
                PanelNote(text: String(localized: "Add your logo to your library in Media › Your library, then pick it here."))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(pictures) { asset in
                            Button {
                                if let picked = brand.logo(from: asset) {
                                    var placed = picked
                                    placed.corner = kit.logo?.corner ?? .topRight
                                    kit.logo = placed
                                }
                            } label: {
                                LibraryAssetTile(
                                    asset: asset, url: brand.library.url(of: asset), status: brand.library.status(of: asset),
                                    order: kit.logo?.name == asset.name ? 1 : nil
                                )
                                .frame(width: 90)
                            }
                            .buttonStyle(.cuePress)
                            .accessibilityIdentifier("edit.brand.logo.\(asset.name)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if kit.logo != nil {
                PanelSegmented(
                    label: String(localized: "Where it goes"),
                    options: BrandLogoCorner.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) },
                    selection: kit.logo?.corner, identifier: "edit.brand.logoCorner"
                ) { kit.logo?.corner = $0 }
                PanelButton(label: String(localized: "No logo"), systemImage: "xmark", identifier: "edit.brand.noLogo") { kit.logo = nil }
            }
        }
    }

    // MARK: - Styles

    private var styles: some View {
        VStack(alignment: .leading, spacing: 12) {
            stylePicker(
                label: String(localized: "Text style"), current: kit.textStyle?.name,
                videoLook: viewModel.edit.textLook ?? viewModel.edit.texts.first(where: { $0.graphic == nil }).map(TextLook.init(of:)),
                saved: brand.savedTextStyles.map { ($0.name, $0.look) }, identifier: "edit.brand.textStyle"
            ) { name, look in kit.textStyle = look.map { BrandKitStyle(name: name, look: $0) } }
            stylePicker(
                label: String(localized: "Caption style"), current: kit.captionStyle?.name,
                videoLook: viewModel.edit.captions.isEmpty ? nil : viewModel.edit.captionCollection.map {
                    MyCaptionStyle(settings: $0, animation: viewModel.edit.captionAnimation)
                },
                saved: brand.savedCaptionStyles.map { ($0.name, $0.look) }, identifier: "edit.brand.captionStyle"
            ) { name, look in kit.captionStyle = look.map { BrandKitStyle(name: name, look: $0) } }
            stylePicker(
                label: String(localized: "Cover style"), current: kit.coverStyle?.name,
                videoLook: viewModel.edit.cover?.composition?.style,
                saved: brand.savedCoverStyles.map { ($0.name, $0.look) }, identifier: "edit.brand.coverStyle"
            ) { name, look in kit.coverStyle = look.map { BrandKitStyle(name: name, look: $0) } }
        }
    }

    /// A style for the kit: none, this video's, or one the creator saved (a copy of it as it is now).
    private func stylePicker<Look>(
        label: String, current: String?, videoLook: Look?, saved: [(String, Look)], identifier: String,
        onPick: @escaping (String, Look?) -> Void
    ) -> some View {
        let thisVideo = String(localized: "This video’s")
        var options: [PanelOption<String>] = [PanelOption("", String(localized: "None"), key: "none")]
        if videoLook != nil { options.append(PanelOption(thisVideo, thisVideo, key: "video")) }
        options += saved.map { PanelOption($0.0, $0.0, key: $0.0) }
        return VStack(alignment: .leading, spacing: 6) {
            PanelRowLabel(label: label)
            PanelChips(options: options, selection: current ?? "", identifier: identifier) { name in
                if name.isEmpty {
                    onPick("", nil)
                } else if name == thisVideo, let videoLook {
                    onPick(name, videoLook)
                } else if let look = saved.first(where: { $0.0 == name })?.1 {
                    onPick(name, look)
                }
            }
        }
    }
}
