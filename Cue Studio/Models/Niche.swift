//
//  Niche.swift
//  Cue Studio
//

import Foundation

/// What a creator talks about, as a broad theme: the first flight offers them all (1.2), each becomes a world in the universe, and My Cue Voice
/// refines each with its subtopics (`VoiceSubtopicCatalog`). The owner (03/11/2026): the first flight asks only general themes ("Travel", not
/// "Budget travel"), the details come later in My Cue Voice, and the list covers as many creators as it can (researched across platform
/// categories, creator-economy reports and creator forums, 03/11/2026). The themes only My Cue Voice offered before are themes like the others
/// (`CreatorProfile.niches(_:joining:details:)`); "Music & arts" kept its id as Music & dance, with Art & design beside it.
nonisolated enum Niche: String, Codable, CaseIterable, Identifiable, Sendable {
    case fitness, food, beauty, fashion, finance, tech, travel, productivity, parenting, lifestyle, wellness, education
    case business, healthcare, law, relationships, homeDIY, booksMovies, musicArts, gaming, sports, pets, cars, realEstate, faith, news
    case comedy, selfImprovement, shopping, artDesign, trades, agriculture, causes, events

    var id: String { rawValue }

    /// The themes the first flight and My Cue Voice offer, the ones that cover the most creators first.
    static let offered: [Niche] = [
        .lifestyle, .beauty, .business, .food, .fitness, .comedy, .fashion, .finance, .education, .tech, .healthcare, .travel, .parenting,
        .selfImprovement, .wellness, .gaming, .musicArts, .relationships, .faith, .sports, .booksMovies, .news, .shopping, .homeDIY, .productivity,
        .realEstate, .pets, .law, .artDesign, .cars, .trades, .agriculture, .causes, .events,
    ]

    /// Short name: script tags, idea lines, prompts.
    var label: String {
        switch self {
        case .lifestyle: String(localized: "Lifestyle")
        case .wellness: String(localized: "Wellness")
        case .beauty: String(localized: "Beauty")
        case .fitness: String(localized: "Fitness")
        case .food: String(localized: "Food")
        case .tech: String(localized: "Tech")
        case .finance: String(localized: "Finance")
        case .education: String(localized: "Education")
        case .fashion: String(localized: "Fashion")
        case .travel: String(localized: "Travel")
        case .productivity: String(localized: "Productivity")
        case .parenting: String(localized: "Parenting")
        default: chipLabel
        }
    }

    /// The theme's name as a chip and as a world in the universe: what the creator picked is what they see everywhere.
    var chipLabel: String {
        switch self {
        case .lifestyle: String(localized: "Lifestyle & daily life")
        case .beauty: String(localized: "Beauty & personal care")
        case .business: String(localized: "Business & marketing")
        case .food: String(localized: "Food & gastronomy")
        case .fitness: String(localized: "Fitness & training")
        case .comedy: String(localized: "Comedy & entertainment")
        case .fashion: String(localized: "Fashion & style")
        case .finance: String(localized: "Money & finance")
        case .education: String(localized: "Education & learning")
        case .tech: String(localized: "Tech & AI")
        case .healthcare: String(localized: "Health & medicine")
        case .travel: String(localized: "Travel")
        case .parenting: String(localized: "Parenting & family")
        case .selfImprovement: String(localized: "Self-improvement")
        case .wellness: String(localized: "Mental health & wellness")
        case .gaming: String(localized: "Gaming")
        case .musicArts: String(localized: "Music & dance")
        case .relationships: String(localized: "Love & relationships")
        case .faith: String(localized: "Faith & spirituality")
        case .sports: String(localized: "Sports")
        case .booksMovies: String(localized: "Books, film & TV")
        case .news: String(localized: "News & current events")
        case .shopping: String(localized: "Shopping & reviews")
        case .homeDIY: String(localized: "Home, decor & DIY")
        case .productivity: String(localized: "Career & productivity")
        case .realEstate: String(localized: "Real estate")
        case .pets: String(localized: "Pets & animals")
        case .law: String(localized: "Law & rights")
        case .artDesign: String(localized: "Art & design")
        case .cars: String(localized: "Cars & motorcycles")
        case .trades: String(localized: "Trades & construction")
        case .agriculture: String(localized: "Farming & rural life")
        case .causes: String(localized: "Causes & social impact")
        case .events: String(localized: "Weddings & events")
        }
    }

    /// What the AI reads (English and in full, whatever the interface language is): "Travel" alone told it little.
    var promptName: String {
        switch self {
        case .lifestyle: "lifestyle and daily life"
        case .beauty: "beauty and personal care"
        case .business: "business, entrepreneurship and marketing"
        case .food: "food and gastronomy"
        case .fitness: "fitness and training"
        case .comedy: "comedy and entertainment"
        case .fashion: "fashion and style"
        case .finance: "money and personal finance"
        case .education: "education and learning"
        case .tech: "technology and AI"
        case .healthcare: "health and medicine"
        case .travel: "travel"
        case .parenting: "parenting and family"
        case .selfImprovement: "self-improvement and personal growth"
        case .wellness: "mental health and wellness"
        case .gaming: "gaming"
        case .musicArts: "music and dance"
        case .relationships: "love and relationships"
        case .faith: "faith and spirituality"
        case .sports: "sports"
        case .booksMovies: "books, film, TV and pop culture"
        case .news: "news and current events"
        case .shopping: "shopping, products and reviews"
        case .homeDIY: "home, decor and DIY"
        case .productivity: "career and productivity"
        case .realEstate: "real estate"
        case .pets: "pets and animals"
        case .law: "law and people's rights"
        case .artDesign: "art and design"
        case .cars: "cars and motorcycles"
        case .trades: "skilled trades and construction"
        case .agriculture: "farming, agribusiness and rural life"
        case .causes: "causes and social impact"
        case .events: "weddings and events"
        }
    }
}
