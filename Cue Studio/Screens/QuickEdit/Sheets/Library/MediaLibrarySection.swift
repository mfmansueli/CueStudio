//
//  MediaLibrarySection.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// "Your library" in Add photo or video: the creator's kept photos, videos and logos, searchable, filtered (All, Favorites,
/// Logos, Videos, Photos), favorites first. Photos and videos are picked in order (`BrandViewModel.libraryPicked`; the sheet's
/// bar continues with them) and go on like picks from Photos (where they go, their part); a logo goes straight on, small over
/// the whole video. Files come in from Photos or Files without
/// leaving the sheet; holding a card renames it, stars it, makes a picture a logo (or back) or removes it (Undo).
struct MediaLibrarySection: View {
    let viewModel: QuickEditViewModel
    /// Only videos: a clip of the sequence is a video.
    let videosOnly: Bool
    let allowsSeveral: Bool
    let onContinue: ([LibraryAsset]) -> Void
    let onLogo: (LibraryAsset) -> Void

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importsFiles = false
    /// Photos, as the system's sheet (from the + menu).
    @State private var picksPhotos = false
    @State private var renaming: LibraryAsset?
    @State private var newName = ""
    @FocusState private var searchFocused: Bool

    private var brand: BrandViewModel { viewModel.brand }
    /// Four to a row on an iPhone, so a whole row shows above the footer at the sheet's middle height.
    private static let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        @Bindable var brand = brand
        // One scroll for the whole library (search, filters, adding, the grid) in the room the sheet leaves it: picking never
        // moves the sheet's controls, and the footer's Continue stays in view.
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !brand.library.assets.isEmpty {
                    // Search, the filter and adding share one row, so a whole row of cards shows above the footer even at the
                    // sheet's middle height.
                    HStack(spacing: 8) {
                        SearchField(text: $brand.librarySearch, prompt: "Search your library", isFocused: $searchFocused)
                            .accessibilityIdentifier("edit.library.search")
                        filterMenu
                        addMenu
                    }
                }
                let assets = brand.shownAssets(videosOnly: videosOnly)
                if brand.library.assets.isEmpty {
                    empty
                    addButtons
                } else if assets.isEmpty {
                    PanelNote(text: String(localized: "Nothing here matches. Try another word or filter."))
                } else {
                    LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 12) {
                        ForEach(assets) { asset in tile(asset) }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            // A filter the sequence doesn't offer (Logos, Photos) goes back to All.
            if videosOnly, ![.all, .favorites, .videos].contains(brand.libraryFilter) { brand.libraryFilter = .all }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await brand.addToLibrary(items)
                photoItems = []
            }
        }
        .photosPicker(isPresented: $picksPhotos, selection: $photoItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos]))
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

    /// The filter, as the system's menu: All, Favorites, Logos, Videos, Photos (in the sequence, only those with videos); filled
    /// while one other than All is on.
    private var filterMenu: some View {
        @Bindable var brand = brand
        let filters = LibraryFilter.allCases.filter { !videosOnly || $0 == .all || $0 == .favorites || $0 == .videos }
        return Menu {
            Picker(String(localized: "Show"), selection: $brand.libraryFilter) {
                ForEach(filters) { filter in Text(filter.label).tag(filter) }
            }
        } label: {
            Image(systemName: brand.libraryFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                .foregroundStyle(brand.libraryFilter == .all ? Palette.ink : Palette.accText)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .background(Palette.fill, in: Circle())
        }
        .accessibilityLabel(Text("Filter"))
        .accessibilityValue(Text(brand.libraryFilter.label))
        .accessibilityIdentifier("edit.library.filter")
    }

    /// "+": the system's menu, to add from Photos or Files.
    private var addMenu: some View {
        Menu {
            Button { picksPhotos = true } label: { Label("Add from Photos", systemImage: "photo.on.rectangle") }
            Button { importsFiles = true } label: { Label("Add from Files", systemImage: "folder") }
        } label: {
            Image(systemName: brand.isAddingToLibrary ? "hourglass" : "plus")
                .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .background(Palette.fill, in: Circle())
        }
        .disabled(brand.isAddingToLibrary)
        .accessibilityLabel(Text("Add to your library"))
        .accessibilityIdentifier("edit.library.add")
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
        let order = brand.libraryPicked.firstIndex(of: asset.id).map { $0 + 1 }
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
            brand.libraryPicked.removeAll { $0 == asset.id }
            brand.removeFromLibrary(asset.id)
        } label: { Label("Remove from library", systemImage: "trash") }
    }

    private func tap(_ asset: LibraryAsset, status: LibraryFileReader.Status) {
        guard status == .ready else {
            viewModel.toast.show(String(localized: "\(asset.name) is missing · remove it from your library"), kind: .problem)
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
        if let index = brand.libraryPicked.firstIndex(of: asset.id) {
            brand.libraryPicked.remove(at: index)
        } else {
            brand.libraryPicked.append(asset.id)
        }
    }
}
