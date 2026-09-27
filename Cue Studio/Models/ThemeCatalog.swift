//
//  ThemeCatalog.swift
//  Cue Studio
//

import Foundation

/// Starter ideas per niche, shown in Generate › Themes before (or without) the model's own
/// suggestions. Local on purpose: trends in real time would need a backend.
nonisolated enum ThemeCatalog {
    /// How many ideas the Themes tab shows at once.
    static let pageSize = 6

    static func ideas(for niche: Niche) -> [ThemeIdea] {
        let raw: [(String, String, ScriptLength)] = switch niche {
        case .lifestyle: [
            (String(localized: "3 things I stopped buying this year"), String(localized: "List"), .minute1),
            (String(localized: "My Sunday reset in 60 seconds"), String(localized: "Routine"), .minute1),
            (String(localized: "What a normal Tuesday really looks like"), String(localized: "Vlog"), .minutes2),
        ]
        case .wellness: [
            (String(localized: "The 5-minute habit that fixed my sleep"), String(localized: "Tip"), .minute1),
            (String(localized: "Hydration myths, busted"), String(localized: "Myth-busting"), .minute1),
            (String(localized: "What I eat on a busy workday"), String(localized: "Routine"), .minute1),
        ]
        case .beauty: [
            (String(localized: "My 5-minute everyday makeup"), String(localized: "Tutorial"), .minute1),
            (String(localized: "Products I regret buying"), String(localized: "Review"), .minute1),
            (String(localized: "Skincare myths I believed for years"), String(localized: "Myth-busting"), .minute1),
        ]
        case .fitness: [
            (String(localized: "The only 3 exercises you need at home"), String(localized: "List"), .minute1),
            (String(localized: "What nobody tells you about starting to run"), String(localized: "Storytime"), .minutes2),
            (String(localized: "Gym mistakes I made for years"), String(localized: "List"), .minute1),
        ]
        case .food: [
            (String(localized: "A 10-minute dinner I make every week"), String(localized: "Tutorial"), .minute1),
            (String(localized: "Kitchen hacks that actually work"), String(localized: "List"), .minute1),
            (String(localized: "The story behind my grandma’s recipe"), String(localized: "Storytime"), .minutes2),
        ]
        case .tech: [
            (String(localized: "iPhone settings I change on day one"), String(localized: "List"), .minute1),
            (String(localized: "Is it worth upgrading this year?"), String(localized: "Opinion"), .minutes2),
            (String(localized: "Apps that replaced my notebook"), String(localized: "List"), .minute1),
        ]
        case .finance: [
            (String(localized: "Compound interest, explained simply"), String(localized: "Explainer"), .minute1),
            (String(localized: "How I budget without spreadsheets"), String(localized: "Tutorial"), .minute1),
            (String(localized: "Money mistakes I made in my 20s"), String(localized: "Storytime"), .minutes2),
        ]
        case .education: [
            (String(localized: "A history fact that sounds fake"), String(localized: "Explainer"), .minute1),
            (String(localized: "How to learn anything faster"), String(localized: "Tips"), .minute1),
            (String(localized: "Where the word “OK” comes from"), String(localized: "Explainer"), .minute1),
        ]
        }
        return raw.map { ThemeIdea(title: $0.0, kind: $0.1, length: $0.2, niche: niche) }
    }

    /// Ideas for the creator's niches (Lifestyle when none is set), rotated by `rotation` so
    /// "New ideas" brings different ones to the top, `pageSize` at a time.
    static func page(for niches: [Niche], rotation: Int) -> [ThemeIdea] {
        let all = (niches.isEmpty ? [.lifestyle] : niches).flatMap(ideas(for:))
        guard !all.isEmpty else { return [] }
        let start = ((rotation % all.count) + all.count) % all.count
        let rotated = Array(all[start...] + all[..<start])
        return Array(rotated.prefix(pageSize))
    }
}
