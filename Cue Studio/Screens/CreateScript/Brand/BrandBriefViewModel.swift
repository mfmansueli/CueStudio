//
//  BrandBriefViewModel.swift
//  Cue Studio
//

import Foundation

/// The brand brief sheet's state (v29 · B): the brand being filled in, which saved brand is picked, and whether it is
/// kept for next time. The ad is only written with a brand and a product, and from nothing else.
@MainActor
@Observable
final class BrandBriefViewModel {
    var draft: BrandBrief
    /// "Save brand": on by default, so the next ad starts from this one.
    var savesBrand = true

    private let store: BrandStore

    init(store: BrandStore) {
        self.store = store
        // The brand used last comes first; a creator with none starts with an empty brief.
        draft = store.brands.first ?? BrandBrief()
    }

    var savedBrands: [BrandBrief] { store.brands }

    /// "✦ Write the ad" is yellow only with a brand and a product.
    var canWrite: Bool { draft.isUsable }

    /// Which saved brand the fields hold (nil: a new one).
    var selectedBrandID: UUID? {
        savedBrands.first { $0.name.caseInsensitiveCompare(draft.name) == .orderedSame }?.id
    }

    func select(_ brand: BrandBrief) {
        draft = brand
    }

    func startNew() {
        draft = BrandBrief()
    }

    /// The brief to write from, saved first when "Save brand" is on. Nil while a brand or a product is missing.
    func commit() -> BrandBrief? {
        guard canWrite else { return nil }
        var brief = draft
        brief.name = brief.name.trimmingCharacters(in: .whitespacesAndNewlines)
        brief.product = brief.product.trimmingCharacters(in: .whitespacesAndNewlines)
        return savesBrand ? (store.save(brief) ?? brief) : brief
    }
}
