//
//  FeatureIntro.swift
//  Cue Studio
//

import Foundation

/// One entry of the discovery catalog (`FeatureCatalog`): which tool, under which campaign, when it fits, where it opens and how it is
/// told. The words are `FeatureID+Copy`'s; what counts as having used it is `FeatureAdoption`'s.
nonisolated struct FeatureIntro: Hashable, Sendable {
    enum Channel: Hashable, Sendable {
        /// A discovery notification (with the creator's yes to "Discover tools and ideas").
        case notification
        /// The introduction in the app, at a quiet moment.
        case inApp
    }

    /// The tool's sign on the introduction: an SF Symbol by name (a string literal), or one of the app's own icons.
    enum Symbol: Hashable, Sendable, ExpressibleByStringLiteral {
        case system(String)
        case cue(CueIcon)

        init(stringLiteral name: String) {
            self = .system(name)
        }
    }

    /// What the introduction says before "Try it", so nothing comes as a surprise: what the tool uses or needs.
    enum Note: Hashable, Sendable {
        /// Runs with Apple Intelligence on this iPhone.
        case appleIntelligence
        /// Listens on this iPhone; a language can need a model the first time.
        case speechModel
        /// A language can need a download before the first translation.
        case translationDownload
        /// Needs another iPhone or iPad with Cue nearby.
        case secondDevice
        /// Only changes what the creator picks; nothing else.
        case nothingChanges
    }

    let feature: FeatureID
    /// Versioned: a new wording or rule is a new campaign, measured on its own.
    let campaignID: String
    let symbol: Symbol
    let requirements: [FeatureRequirement]
    let target: DiscoveryTarget
    let channels: Set<Channel>
    let note: Note
}

nonisolated extension FeatureIntro.Note {
    /// What the tool uses or needs, said before "Try it".
    var text: String {
        switch self {
        case .appleIntelligence: String(localized: "Uses Apple Intelligence on this iPhone.")
        case .speechModel: String(localized: "Listens on this iPhone. Some languages download a model the first time.")
        case .translationDownload: String(localized: "Some languages download before the first translation.")
        case .secondDevice: String(localized: "Needs another iPhone or iPad with Cue, nearby.")
        case .nothingChanges: String(localized: "Free. Nothing changes until you choose.")
        }
    }
}
