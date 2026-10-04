//
//  CreatorRole.swift
//  Cue Studio
//

import Foundation

/// "What kind of creator are you?", the first question of My Cue Voice: the closest of eight. It
/// tells the AI who is talking (and so how they say "I" or "we"), and which tones are common for them.
nonisolated enum CreatorRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case personal, entertainer, expert, educator, business, brands, news, community

    var id: String { rawValue }

    var label: String {
        switch self {
        case .personal: String(localized: "Lifestyle & personal")
        case .entertainer: String(localized: "Entertainer")
        case .expert: String(localized: "Expert, coach or pro")
        case .educator: String(localized: "Teacher or explainer")
        case .business: String(localized: "My own business")
        case .brands: String(localized: "Content for brands")
        case .news: String(localized: "News & commentary")
        case .community: String(localized: "Community or cause")
        }
    }

    var examples: String {
        switch self {
        case .personal: String(localized: "Routine, style, opinions, vlogs")
        case .entertainer: String(localized: "Comedy, sketches, music, reacts")
        case .expert: String(localized: "Trainer, doctor, lawyer, consultant")
        case .educator: String(localized: "Classes, study, how things work")
        case .business: String(localized: "Shop, salon, studio, service")
        case .brands: String(localized: "UGC, reviews, social media manager")
        case .news: String(localized: "Report, analyze, review, react")
        case .community: String(localized: "Faith, nonprofit, activism, politics")
        }
    }

    var systemImage: String {
        switch self {
        case .personal: "person.crop.circle"
        case .entertainer: "theatermasks"
        case .expert: "star"
        case .educator: "graduationcap"
        case .business: "storefront"
        case .brands: "tag"
        case .news: "newspaper"
        case .community: "heart.circle"
        }
    }

    /// The tones that are common for this kind of creator: suggested, never chosen for them.
    var commonSounds: [VoiceSound] {
        switch self {
        case .personal: [.casual, .funny]
        case .entertainer: [.funny, .casual]
        case .expert: [.confident, .educational]
        case .educator: [.educational, .casual]
        case .business: [.casual, .professional]
        case .brands: [.casual, .energetic]
        case .news: [.professional, .confident]
        case .community: [.energetic, .casual]
        }
    }

    /// Who is talking, for the AI: businesses and brands say "we".
    var speaksAsWe: Bool { self == .business || self == .brands }
}
