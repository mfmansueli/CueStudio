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

    init(repository: BrandRepository = LocalBrandRepository()) {
        self.repository = repository
    }

    func load() {
        do {
            brands = try repository.load()
        } catch {
            logger.error("Could not load brands: \(error.localizedDescription)")
        }
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

    func brand(id: UUID?) -> BrandBrief? {
        guard let id else { return nil }
        return brands.first { $0.id == id }
    }

    /// The brief an `ad` script saved before v29 carried, saved once as a brand. Doing it again for the same brand
    /// changes nothing. Returns the brand, or nil when the old brief had no brand.
    @discardableResult
    func adopt(legacyAdBrief brief: [String: String]) -> BrandBrief? {
        let legacy = BrandBrief(legacyAdBrief: brief)
        guard legacy.isUsable else { return nil }
        if let existing = brands.first(where: { $0.name.caseInsensitiveCompare(legacy.name) == .orderedSame }) { return existing }
        return save(legacy)
    }

    private func persist() {
        do {
            try repository.save(brands)
        } catch {
            logger.error("Could not save brands: \(error.localizedDescription)")
        }
    }
}
