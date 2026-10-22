//
//  BrandStore.swift
//  Cue Studio
//

import Foundation
import os

/// The creator's saved brands for sponsored ads, most recently used first. Stays on this iPhone.
@MainActor
@Observable
final class BrandStore {
    private(set) var brands: [BrandBrief] = []

    private let repository: BrandRepository
    private let logger = Logger(subsystem: "studio.cue", category: "BrandStore")
    /// False when the brands on disk couldn't be read: writing would replace them with what's in memory.
    @ObservationIgnored private var canSave = true

    init(repository: BrandRepository = LocalBrandRepository()) {
        self.repository = repository
    }

    func load() {
        do {
            brands = try repository.load()
            canSave = true
        } catch {
            // Saving now would write the brands in memory (none) over the ones on disk.
            canSave = false
            logger.error("Could not load brands: \(error.localizedDescription)")
        }
    }

    /// The brands couldn't be read at launch: read them again now, keeping (first) the ones saved since.
    func reloadIfUnread() {
        guard !canSave, let saved = try? repository.load() else { return }
        let made = Set(brands.map(\.id))
        brands += saved.filter { !made.contains($0.id) }
        canSave = true
    }

    /// Saves a brand and puts it first. A brand with the same name (any case) is updated, not duplicated. Returns the
    /// one stored, or nil when it lacks a brand or a product (`BrandBrief.isUsable`).
    @discardableResult
    func save(_ brief: BrandBrief) -> BrandBrief? {
        guard brief.isUsable else { return nil }
        var brief = brief
        brief.name = brief.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = brands.firstIndex(where: { $0.id == brief.id || $0.name.caseInsensitiveCompare(brief.name) == .orderedSame }) {
            brief.id = brands[index].id
            brands.remove(at: index)
        }
        brands.insert(brief, at: 0)
        persist()
        return brief
    }

    func remove(_ id: UUID) {
        brands.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        reloadIfUnread()
        guard canSave else {
            logger.error("Not saving brands: the ones on disk still can't be read")
            return
        }
        do {
            try repository.save(brands)
        } catch {
            logger.error("Could not save brands: \(error.localizedDescription)")
        }
    }
}
