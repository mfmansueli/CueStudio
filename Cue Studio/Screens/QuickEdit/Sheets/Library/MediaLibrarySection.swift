//
//  MediaLibrarySection.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// "Your library" in Add photo or video: the creator's kept photos, videos and logos, searchable, filtered (All, Favorites,
/// Logos, Videos, Photos), favorites first. Photos and videos are picked in order and go on like picks from Photos (where
/// they go, their part); a logo goes straight on, small over the whole video. Files come in from Photos or Files without
/// leaving the sheet; holding a card renames it, stars it, makes a picture a logo (or back) or removes it (Undo).
struct MediaLibrarySection: View {
    let viewModel: QuickEditViewModel
    /// Only videos: a clip of the sequence is a video.
    let videosOnly: Bool
    let allowsSeveral: Bool
    let onContinue: ([LibraryAsset]) -> Void
    let onLogo: (LibraryAsset) -> Void

    @State private var picked: [UUID] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importsFiles = false
    @State private var renaming: LibraryAsset?
    @State private var newName = ""
    @FocusState private var searchFocused: Bool

    private var brand: BrandViewModel { viewModel.brand }
    private static let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        @Bindable var brand = brand
        VStack(alignment: .leading, spacing: 10) {
            if !brand.library.assets.isEmpty {
                SearchField(text: $brand.librarySearch, prompt: "Search your library", isFocused: $searchFocused)
                    .accessibilityIdentifier("edit.library.search")
                PanelChips(
                    options: LibraryFilter.allCases.filter { !videosOnly || $0 == .all || $0 == .favorites || $0 == .videos }
                        .map { PanelOption($0, $0.label, key: $0.rawValue) },
                    selection: brand.libraryFilter, identifier: "edit.library.filter"
                ) { brand.libraryFilter = $0 }
            }
            addButtons
            let assets = brand.shownAssets(videosOnly: videosOnly)
            if brand.library.assets.isEmpty {
                empty
            } else if assets.isEmpty {
                PanelNote(text: String(localized: "Nothing here matches. Try another word or filter."))
            } else {
                LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 12) {
                    ForEach(assets) { asset in tile(asset) }
                }
            }
            if !picked.isEmpty {
                PanelButton(
                    label: String(localized: "Continue · \(picked.count)"), isPrimary: true, identifier: "edit.library.continue"
                ) {
                    onContinue(picked.compactMap { brand.library.asset($0) })
                }
                .padding(.bottom, 8)
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await brand.addToLibrary(items)
                photoItems = []
            }
        }
        .fileImporter(isPresented: $importsFiles, allowedContentTypes: [.image, .movie], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { await brand.addFilesToLibrary(urls) }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let renaming { brand.library.rename(renaming.id, to: newName) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private var addButtons: some View {
        let ink = Palette.ink
        let fill = Palette.fill
        let height = Metrics.hitTarget
        let radius = Metrics.fieldRadius
        return HStack(spacing: 8) {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                // Built here: the picker's label closure isn't on the main actor.
                Label("Add from Photos", systemImage: "photo.on.rectangle")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .accessibilityIdentifier("edit.library.addPhotos")
            Button {
                importsFiles = true
            } label: {
                Label("Add from Files", systemImage: "folder")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                    .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            }
            .buttonStyle(.cuePress)
            .accessibilityIdentifier("edit.library.addFiles")
        }
        .disabled(brand.isAddingToLibrary)
        .overlay {
            if brand.isAddingToLibrary { ProgressView().tint(Palette.ink) }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your library is empty")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("Keep your logo, photos and videos here to use them in any video. Videos you make keep their own copy.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.library.empty")
    }

    private func tile(_ asset: LibraryAsset) -> some View {
        let status = brand.library.status(of: asset)
        let order = picked.firstIndex(of: asset.id).map { $0 + 1 }
        return Button {
            tap(asset, status: status)
        } label: {
            LibraryAssetTile(asset: asset, url: brand.library.url(of: asset), status: status, order: order)
        }
        .buttonStyle(.cuePress)
        .task(id: asset.id) { await brand.library.checkStatus(of: asset) }
        .contextMenu { menu(asset) }
        .accessibilityIdentifier("edit.library.asset.\(asset.name)")
    }

    @ViewBuilder
    private func menu(_ asset: LibraryAsset) -> some View {
        Button {
            newName = asset.name
            renaming = asset
        } label: { Label("Rename", systemImage: "pencil") }
        Button {
            brand.library.toggleFavorite(asset.id)
        } label: {
            asset.isFavorite
                ? Label("Remove from favorites", systemImage: "star.slash")
                : Label("Add to favorites", systemImage: "star")
        }
        if asset.kind == .photo {
            Button { brand.library.setKind(asset.id, .logo) } label: { Label("Use as a logo", systemImage: "seal") }
        } else if asset.kind == .logo {
            Button { brand.library.setKind(asset.id, .photo) } label: { Label("Use as a photo", systemImage: "photo") }
        }
        Button(role: .destructive) {
            picked.removeAll { $0 == asset.id }
            brand.removeFromLibrary(asset.id)
        } label: { Label("Remove from library", systemImage: "trash") }
    }

    private func tap(_ asset: LibraryAsset, status: LibraryFileReader.Status) {
        guard status == .ready else {
            viewModel.toast.show(String(localized: "\(asset.name) is missing · remove it from your library"))
            return
        }
        Haptics.selection()
        if asset.kind == .logo, !videosOnly {
            onLogo(asset)
            return
        }
        if !allowsSeveral {
            onContinue([asset])
            return
        }
        if let index = picked.firstIndex(of: asset.id) {
            picked.remove(at: index)
        } else {
            picked.append(asset.id)
        }
    }
}
