//
//  BrandBrief.swift
//  Cue Studio
//

import Foundation

/// What a sponsored ad may say (v29): the brand and the product are required, and the AI uses only what is here, so it
/// never invents a claim. "Paid partnership · #ad" is always on, so it has no switch to store. Saved brands are reused
/// (`BrandStore`).
nonisolated struct BrandBrief: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var product: String = ""
    /// Claims the brand approved.
    var mustSay: String = ""
    /// What the ad must not claim or mention (health claims, competitors).
    var neverSay: String = ""
    var link: String = ""
    var code: String = ""

    init(
        id: UUID = UUID(), name: String = "", product: String = "", mustSay: String = "", neverSay: String = "",
        link: String = "", code: String = ""
    ) {
        self.id = id
        self.name = name
        self.product = product
        self.mustSay = mustSay
        self.neverSay = neverSay
        self.link = link
        self.code = code
    }

    /// "✦ Write the ad" needs a brand and a product.
    var isUsable: Bool { !name.trimmed.isEmpty && !product.trimmed.isEmpty }

    /// The brief of an `ad` script saved before v29: the old fields become the brand. Nothing is lost: the
    /// old "Brand & product" text is the brand, its benefit is the product and what to say, and the code or link stays.
    init(legacyAdBrief brief: [String: String]) {
        let brand = (brief["brand"] ?? "").trimmed
        let benefit = (brief["benefit"] ?? "").trimmed
        let offer = (brief["offer"] ?? "").trimmed
        self.init(name: brand, product: benefit.isEmpty ? brand : benefit, mustSay: benefit)
        // "oatandco.com/maya" is a link; "Code MORNING for 20% off" is kept whole as the code.
        if !offer.isEmpty {
            if offer.contains(" ") || !offer.contains(".") { code = offer } else { link = offer }
        }
    }
}

private nonisolated extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
