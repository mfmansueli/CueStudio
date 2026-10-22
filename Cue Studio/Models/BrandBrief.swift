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
}

private nonisolated extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
