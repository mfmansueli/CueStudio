//
//  MediaLibraryStore.swift
//  Cue Studio
//

import Foundation
import os

/// The creator's library: photos, videos and logos kept to reuse in any video, on this iPhone. Files come in from a pick or
/// from a video's media as links to bytes Cue already has (`MediaLibraryFiles`), once each (the same bytes again are the
/// same asset); they go into a video as the video's own link (`media(for:)`), so removing one from the library, or a video,
/// never breaks the other. A removed asset's file stays until the next launch's sweep (`LibraryFileSweep`), so Undo can put
/// it back.
@MainActor
@Observable
final class MediaLibraryStore {
    private(set) var assets: [LibraryAsset] = []
    /// What each asset's file was found to be this session (missing, unreadable), read when its card shows.
    private(set) var statuses: [UUID: LibraryFileReader.Status] = [:]

    @ObservationIgnored let directory: URL
    @ObservationIgnored private let repository: MediaLibraryRepository
    @ObservationIgnored private let logger = Logger(subsystem: "studio.cue", category: "MediaLibrary")
    /// False when the list on disk couldn't be read: writing would replace it with what's in memory.
    @ObservationIgnored private var canSave = true

    init(repository: MediaLibraryRepository = LocalMediaLibraryRepository(), directory: URL = MediaLibraryFiles.directory) {
        self.repository = repository
        self.directory = directory
    }

    func load() {
        do {
            assets = try repository.load()
            canSave = true
        } catch {
            canSave = false
            logger.error("Could not load the media library: \(error.localizedDescription)")
        }
    }

    /// The list couldn't be read at launch: read it again now, keeping (first) what came in since.
    func reloadIfUnread() {
        if mergeUnread() { persist() }
    }

    /// The list on disk, read now if it couldn't be before, with what came in since; whether it was read.
    private func mergeUnread() -> Bool {
        guard !canSave, let saved = try? repository.load() else { return false }
        let made = Set(assets.map(\.id))
        assets += saved.filter { !made.contains($0.id) }
        canSave = true
        return true
    }

    /// The assets `filter` and `search` let through, favorites first, then the latest added or used.
    func assets(in filter: LibraryFilter, matching search: String = "") -> [LibraryAsset] {
        assets.filter { filter.includes($0) && $0.matches(search) }
            .sorted { ($0.isFavorite ? 1 : 0, $0.recency) > ($1.isFavorite ? 1 : 0, $1.recency) }
    }

    func asset(_ id: UUID) -> LibraryAsset? {
        assets.first { $0.id == id }
    }

    func url(of asset: LibraryAsset) -> URL {
        MediaLibraryFiles.url(for: asset.fileName, in: directory)
    }

    enum Addition: Equatable {
        case added(LibraryAsset)
        /// The same bytes were already in the library.
        case alreadyThere(LibraryAsset)
    }

    /// Keeps the file at `source` (one Cue has: an import, a video's media), named `name` (or after its kind and today), as a
    /// logo when it is a see-through picture or `kind` says so. The same bytes twice are one asset.
    func add(fileAt source: URL, name: String? = nil, kind: LibraryAssetKind? = nil) async throws -> Addition {
        let fingerprint = try await Task.detached { try MediaLibraryFiles.fingerprint(of: source) }.value
        if let same = assets.first(where: { $0.fingerprint == fingerprint }), MediaLibraryFiles.exists(same.fileName, in: directory) {
            return .alreadyThere(same)
        }
        let description = try await LibraryFileReader.describe(source)
        let fileName = try MediaLibraryFiles.keep(source, in: directory)
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: source.path(percentEncoded: false)))?[.size] as? NSNumber)?.int64Value ?? 0
        let finalKind = description.kind == .video ? .video : (kind ?? description.kind)
        let asset = LibraryAsset(
            name: name ?? defaultName(for: finalKind), kind: finalKind, fileName: fileName, aspect: description.aspect,
            duration: description.duration, hasSound: description.hasSound, fingerprint: fingerprint, byteCount: bytes
        )
        assets.removeAll { $0.fingerprint == fingerprint }
        assets.append(asset)
        persist()
        return .added(asset)
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.name = String(trimmed.prefix(60)) }
    }

    func toggleFavorite(_ id: UUID) {
        update(id) { $0.isFavorite.toggle() }
    }

    /// A picture as a logo or a photo (a video stays a video).
    func setKind(_ id: UUID, _ kind: LibraryAssetKind) {
        update(id) { asset in
            guard asset.kind != .video, kind != .video else { return }
            asset.kind = kind
        }
    }

    /// Takes the asset out of the library; its file stays for this session (Undo puts it back) and goes at a later launch.
    /// Videos that use it are untouched: they have their own link.
    @discardableResult
    func remove(_ id: UUID) -> LibraryAsset? {
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = assets.remove(at: index)
        persist()
        return removed
    }

    func restore(_ asset: LibraryAsset) {
        guard !assets.contains(where: { $0.id == asset.id }) else { return }
        assets.append(asset)
        persist()
    }

    /// The asset as a video's own file (a link to the same bytes in `EditMediaFiles`), and it is marked used now.
    func media(for asset: LibraryAsset) throws -> ImportedMedia {
        let source = url(of: asset)
        guard FileManager.default.fileExists(atPath: source.path(percentEncoded: false)) else {
            statuses[asset.id] = .missing
            throw EditMediaImportError.unreadable
        }
        let name = try EditMediaFiles.link(source)
        update(asset.id) { $0.usedAt = .now }
        return ImportedMedia(kind: asset.kind.mediaKind, fileName: name, aspect: asset.aspect, duration: asset.duration, hasSound: asset.hasSound)
    }

    /// Reads whether the asset's file is still there and readable (once a session).
    func checkStatus(of asset: LibraryAsset) async {
        guard statuses[asset.id] == nil else { return }
        statuses[asset.id] = await LibraryFileReader.status(of: url(of: asset), kind: asset.kind)
    }

    func status(of asset: LibraryAsset) -> LibraryFileReader.Status {
        statuses[asset.id] ?? .ready
    }

    /// "Delete my Cue data".
    func eraseAll() {
        assets = []
        statuses = [:]
        MediaLibraryFiles.removeAll(in: directory)
        canSave = true
    }

    // MARK: - Private

    private func update(_ id: UUID, _ change: (inout LibraryAsset) -> Void) {
        guard let index = assets.firstIndex(where: { $0.id == id }) else { return }
        let before = assets[index]
        change(&assets[index])
        if assets[index] != before { persist() }
    }

    /// "Logo 3", "Video 2": the next free number of its kind.
    private func defaultName(for kind: LibraryAssetKind) -> String {
        let taken = Set(assets.map(\.name))
        var number = assets.filter { $0.kind == kind }.count + 1
        while taken.contains("\(kind.label) \(number)") { number += 1 }
        return "\(kind.label) \(number)"
    }

    private func persist() {
        _ = mergeUnread()
        guard canSave else {
            logger.error("Not saving the media library: the list on disk still can't be read")
            return
        }
        do {
            try repository.save(assets)
        } catch {
            logger.error("Could not save the media library: \(error.localizedDescription)")
        }
    }
}
