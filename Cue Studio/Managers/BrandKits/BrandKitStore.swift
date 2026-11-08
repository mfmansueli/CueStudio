//
//  BrandKitStore.swift
//  Cue Studio
//

import Foundation
import os

/// The creator's brand kits, on this iPhone, most recently changed first. Changing a kit never changes a video: a video keeps
/// what a kit put on it, as its own. A kit's logo is the kit's own link to the picture (`BrandKitFiles`); a removed kit's
/// logo file stays until a later launch's sweep (`LibraryFileSweep`), so Undo can put the kit back whole.
@MainActor
@Observable
final class BrandKitStore {
    private(set) var kits: [BrandKit] = []

    @ObservationIgnored let directory: URL
    @ObservationIgnored private let repository: BrandKitRepository
    @ObservationIgnored private let logger = Logger(subsystem: "studio.cue", category: "BrandKits")
    /// False when the kits on disk couldn't be read: writing would replace them with what's in memory.
    @ObservationIgnored private var canSave = true

    init(repository: BrandKitRepository = LocalBrandKitRepository(), directory: URL = BrandKitFiles.directory) {
        self.repository = repository
        self.directory = directory
    }

    func load() {
        do {
            kits = try repository.load().sorted { $0.updatedAt > $1.updatedAt }
            canSave = true
        } catch {
            canSave = false
            logger.error("Could not load brand kits: \(error.localizedDescription)")
        }
    }

    /// The kits couldn't be read at launch: read them again now, keeping (first) the ones saved since.
    func reloadIfUnread() {
        if mergeUnread() { persist() }
    }

    /// The kits on disk, read now if they couldn't be before, with the ones saved since; whether they were read.
    private func mergeUnread() -> Bool {
        guard !canSave, let saved = try? repository.load() else { return false }
        let made = Set(kits.map(\.id))
        kits += saved.filter { !made.contains($0.id) }
        kits.sort { $0.updatedAt > $1.updatedAt }
        canSave = true
        return true
    }

    func kit(_ id: UUID) -> BrandKit? {
        kits.first { $0.id == id }
    }

    /// The kit new videos open in, if the creator chose one.
    var newVideoKit: BrandKit? {
        kits.first { $0.usesOnNewVideos == true }
    }

    /// Saves `kit` (new, or changed), first in the list. A kit saved for new videos is the only one: another that was stops being.
    func save(_ kit: BrandKit) {
        var kit = kit
        kit.name = String(kit.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if kit.name.isEmpty { kit.name = nextName() }
        kit.colors = Array(kit.colors.prefix(BrandKit.maximumColors))
        kit.updatedAt = .now
        if kit.usesOnNewVideos != true { kit.usesOnNewVideos = nil }
        kits.removeAll { $0.id == kit.id }
        if kit.usesOnNewVideos == true {
            for index in kits.indices { kits[index].usesOnNewVideos = nil }
        }
        kits.insert(kit, at: 0)
        persist()
    }

    /// "Brand kit", "Brand kit 2"…
    func nextName() -> String {
        let base = String(localized: "Brand kit")
        let taken = Set(kits.map(\.name))
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    /// A copy named "<name> copy", with its own link to the logo.
    @discardableResult
    func duplicate(_ id: UUID) -> BrandKit? {
        guard var copy = kit(id) else { return nil }
        copy.id = UUID()
        copy.name = String(localized: "\(copy.name) copy")
        copy.createdAt = .now
        copy.usesOnNewVideos = nil
        if let logo = copy.logo { copy.logo?.fileName = (try? keepLogo(at: url(of: logo))) ?? logo.fileName }
        save(copy)
        return copy
    }

    /// Takes the kit out; its logo file stays until a later launch, so `restore` puts it back whole.
    @discardableResult
    func remove(_ id: UUID) -> BrandKit? {
        guard let index = kits.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = kits.remove(at: index)
        persist()
        return removed
    }

    func restore(_ kit: BrandKit) {
        guard !kits.contains(where: { $0.id == kit.id }) else { return }
        var kit = kit
        // Put back after another took its place for new videos: that one stays.
        if newVideoKit != nil { kit.usesOnNewVideos = nil }
        kits.append(kit)
        kits.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    /// The picture at `source` as a kit's logo file (a link to its bytes, or a copy).
    func keepLogo(at source: URL) throws -> String {
        try MediaLibraryFiles.keep(source, in: directory)
    }

    func url(of logo: BrandKitLogo) -> URL {
        BrandKitFiles.url(for: logo.fileName, in: directory)
    }

    /// Whether the kit's logo file is still here.
    func hasLogoFile(_ kit: BrandKit) -> Bool {
        guard let logo = kit.logo else { return false }
        return FileManager.default.fileExists(atPath: url(of: logo).path(percentEncoded: false))
    }

    /// "Delete my Cue data".
    func eraseAll() {
        kits = []
        BrandKitFiles.removeAll(in: directory)
        canSave = true
    }

    private func persist() {
        _ = mergeUnread()
        guard canSave else {
            logger.error("Not saving brand kits: the ones on disk still can't be read")
            return
        }
        do {
            try repository.save(kits)
        } catch {
            logger.error("Could not save brand kits: \(error.localizedDescription)")
        }
    }
}
