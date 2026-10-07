//
//  VoiceTopic.swift
//  Cue Studio
//

import Foundation

/// The topics only My Cue Voice offers, next to the ten the first flight does (`Niche`): what a creator talks about when it isn't one of those.
/// They tell the AI what the videos are about and nothing else: they are not worlds in the universe and never get a color there (decision of
/// 6 Oct 2026), which is why they are not `Niche`s.
nonisolated enum VoiceTopic: String, Codable, CaseIterable, Identifiable, Sendable {
    case gaming, realEstate, musicArts, pets, homeDIY, healthcare, business, study, relationships, faith, news, cars, sports, languages, booksMovies

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gaming: String(localized: "Gaming")
        case .realEstate: String(localized: "Real estate")
        case .musicArts: String(localized: "Music & arts")
        case .pets: String(localized: "Pets & animals")
        case .homeDIY: String(localized: "Home & DIY")
        case .healthcare: String(localized: "Health & medicine")
        case .business: String(localized: "Business & marketing")
        case .study: String(localized: "Study & exams")
        case .relationships: String(localized: "Relationships")
        case .faith: String(localized: "Faith & spirituality")
        case .news: String(localized: "News & current events")
        case .cars: String(localized: "Cars & motorcycles")
        case .sports: String(localized: "Sports")
        case .languages: String(localized: "Languages")
        case .booksMovies: String(localized: "Books, film & TV")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .gaming: "gaming"
        case .realEstate: "real estate"
        case .musicArts: "music and arts"
        case .pets: "pets and animals"
        case .homeDIY: "home and DIY"
        case .healthcare: "health and medicine"
        case .business: "business and marketing"
        case .study: "studying and exams"
        case .relationships: "relationships"
        case .faith: "faith and spirituality"
        case .news: "news and current events"
        case .cars: "cars and motorcycles"
        case .sports: "sports"
        case .languages: "language learning"
        case .booksMovies: "books, film and TV"
        }
    }
}
