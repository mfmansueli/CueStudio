//
//  IdeaLibraryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The idea library the app holds (`IdeaLibrary`, `IdeaLibraryPack`): a pack for each of Cue's 20 languages, about thirty to forty whole briefs a
/// first-flight topic in the pack's own language, read as starters.
struct IdeaLibraryTests {
    /// The String Catalog's languages.
    static let localizations = [
        "en", "ar", "da", "de", "es", "fr", "hi", "id", "it", "ja", "ko", "nb", "nl", "pt", "sv", "th", "tr", "vi", "zh-Hans", "zh-Hant",
    ]

    @Test func theWriterAsksForEveryThemeOnce() {
        let asked = IdeaLibraryDeviceTests.pairs.flatMap(\.self)
        #expect(asked.count == Set(asked).count)
        #expect(Set(asked) == Set(Niche.offered))
    }

    @Test(arguments: Self.localizations)
    func everyLanguageHasAPackAboutEveryTopic(_ localization: String) throws {
        let pack = try #require(IdeaLibrary.load(localization), "No pack for \(localization)")
        #expect(pack.language == localization)
        #expect(pack.version == IdeaLibraryPack.currentVersion)
        // Every theme the first flight offers (the 24 added on 03/11/2026 too).
        for niche in Niche.offered {
            let ideas = pack.ideas.filter { $0.topic == niche.rawValue }
            #expect(ideas.count >= 30, "\(localization) \(niche.rawValue): \(ideas.count)")
            #expect(Set(ideas.map(\.title)).count == ideas.count, "\(localization) \(niche.rawValue): a title twice")
            #expect(Set(ideas.map(\.angle)).count >= 12, "\(localization) \(niche.rawValue): few angles")
        }
        for idea in pack.ideas {
            #expect(IdeaAngle(rawValue: idea.angle) != nil && Niche(rawValue: idea.topic) != nil)
            #expect(!idea.title.isEmpty && !idea.pointOfView.isEmpty && !idea.openingLine.isEmpty)
        }
        // What the card and the field get: within the card's limit, like the model's ideas, and the field's 200.
        for idea in Niche.offered.flatMap({ IdeaLibrary.ideas(for: $0, in: pack) }) {
            let brief = try #require(idea.brief)
            #expect(brief.fitted(to: IdeaBriefReader.cardLimit) == brief, "\(localization): \(idea.title)")
            #expect(brief.composerText.count <= IdeaPromptDraft.maxCharacters, "\(localization): \(idea.title)")
            #expect(idea.title == brief.subject)
        }
    }

    @Test func aPacksIdeasAreStartersWithWholeBriefs() throws {
        let pack = IdeaLibraryPack(language: "pt", ideas: [
            .init(topic: "beauty", angle: "myth", title: "Protetor com cor substitui a base?", pointOfView: "Compare cobertura e proteção.",
                  openingLine: "Muita gente troca a base pelo protetor com cor."),
            .init(topic: "food", angle: "list", title: "Três temperos para arroz", pointOfView: "Mostre cada um.", openingLine: "Arroz sem graça nunca mais."),
            .init(topic: "beauty", angle: "unknown", title: "Ignored", pointOfView: "x", openingLine: "y"),
        ])
        let ideas = IdeaLibrary.ideas(for: .beauty, in: pack)
        #expect(ideas.count == 1)
        let idea = try #require(ideas.first)
        #expect(idea.angle == nil, "a starter, shown once (not the model's)")
        #expect(idea.kind == IdeaAngle.myth.kind)
        #expect(idea.brief?.angle == "Compare cobertura e proteção.")
        #expect(idea.brief?.angleKind == "myth")
        #expect(idea.brief?.topicKey == "beauty")
        #expect(idea.brief?.language == "pt")
        #expect(IdeaLibrary.ideas(for: .beauty, in: nil).isEmpty)
    }
}
