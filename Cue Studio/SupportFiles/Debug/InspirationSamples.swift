//
//  InspirationSamples.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Ideas with a whole brief, as Find inspiration shows them once the model writes briefs: for previews and the design catalogue
/// (`-uiTestCatalogue inspire`).
enum InspirationSamples {
    static let finance: ThemeIdea = {
        var idea = ThemeIdea(title: "Why saving feels harder than spending", kind: "Explainer", length: .minute1, niche: .finance)
        idea.brief = IdeaBrief(
            subject: "Saving money", angle: "Explain one small habit that makes saving easier.",
            openingLine: "Saving isn't just about willpower. It's about what you make automatic.", language: "en"
        )
        return idea
    }()

    static let fitness: ThemeIdea = {
        var idea = ThemeIdea(title: "The desk stretches nobody does", kind: "List", length: .minute1, niche: .fitness)
        idea.brief = IdeaBrief(
            subject: "Desk stretches", angle: "the three that undo a day of sitting, and why people skip them",
            openingLine: "If your back hurts by 3 p.m., this one's for you.", subtopic: "Yoga & stretching", language: "en"
        )
        return idea
    }()

    /// A starter from before briefs: its title alone.
    static let titleOnly = ThemeIdea(title: "3 things I stopped buying this year", kind: "List", length: .minute1, niche: .lifestyle)

    static let note: ThemeIdea = {
        var idea = ThemeIdea(title: "film the market at dawn, before the stalls open", kind: "", length: .minute1, niche: .lifestyle)
        idea.logbookID = UUID()
        return idea
    }()
}
#endif
