//
//  ThemeCatalogTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ThemeCatalog")
struct ThemeCatalogTests {
    @Test func everyFirstFlightTopicHasSixStartersAndTheOldOnesKeepTheirThree() {
        for niche in Niche.offered {
            #expect(ThemeCatalog.ideas(for: niche).count == 6, "\(niche)")
        }
        #expect(ThemeCatalog.ideas(for: .wellness).count == 3)
        #expect(ThemeCatalog.ideas(for: .education).count == 3)
    }

    @Test func everyStarterIsAWholeBriefThatFitsTheComposer() {
        for niche in Niche.allCases {
            for idea in ThemeCatalog.ideas(for: niche) {
                guard let brief = idea.brief else {
                    Issue.record("\(idea.title) has no brief")
                    continue
                }
                #expect(brief.subject == idea.title)
                #expect(!brief.angle.isEmpty && !brief.openingLine.isEmpty)
                #expect(brief.angleKind.flatMap(IdeaAngle.init(rawValue:)) != nil)
                #expect(brief.topicKey == niche.rawValue)
                #expect(brief.composerText.count <= IdeaPromptDraft.maxCharacters, "\(idea.title)")
                #expect(!brief.composerText.contains("…"), "a starter fits whole: \(idea.title)")
            }
        }
    }

    @Test func noStarterIsSaidTwice() {
        let all = Niche.allCases.flatMap(ThemeCatalog.ideas(for:))
        #expect(Set(all.map(\.title)).count == all.count)
        #expect(Set(all.compactMap(\.brief?.openingLine)).count == all.count)
    }

    @Test func aTopicCueHasNoStartersForGetsStartersMadeFromItsNameAndSubtopics() {
        let topic = IdeaTopic(name: "language learning", label: "Languages", niche: nil, subtopics: ["Italian"])
        let ideas = ThemeCatalog.ideas(for: topic)
        #expect(ideas.count >= 6)
        #expect(ideas.allSatisfy { $0.topic == "Languages" && IdeaTopicFilter.topic(topic).includes($0) })
        #expect(ideas[0].title.contains("Languages"))
        #expect(ideas[1].title.contains("Italian") && ideas[1].brief?.subtopic == "Italian")
        #expect(ideas.allSatisfy { $0.brief?.openingLine.contains("Languages") == true || $0.brief?.openingLine.contains("Italian") == true })
        #expect(Set(ideas.compactMap(\.brief?.angleKind)).count == ideas.count, "each looks at it another way")
        #expect(ideas.allSatisfy { $0.angle == nil }, "a starter, not the model's")
    }

    @Test func withNoTopicTheStartersAreEverydayOnesInTurn() {
        let general = ThemeCatalog.ideas(for: [IdeaTopic]())
        #expect(general.prefix(3).map(\.niche) == [.lifestyle, .productivity, .food])
    }

    @Test func severalTopicsTakeTurns() {
        let topics = [Niche.finance, .travel].map { IdeaTopic(name: $0.promptName, label: $0.label, niche: $0) }
        #expect(ThemeCatalog.ideas(for: topics).prefix(4).map(\.niche) == [.finance, .travel, .finance, .travel])
    }

    @Test func twoNichesFillAPageOfSix() {
        let page = ThemeCatalog.page(for: [.lifestyle, .wellness], rotation: 0)
        #expect(page.count == 6)
        #expect(page.first?.title == "3 things I stopped buying this year")
    }

    @Test func noNicheFallsBackToLifestyle() {
        #expect(ThemeCatalog.page(for: [], rotation: 0).allSatisfy { $0.niche == .lifestyle })
    }

    @Test func rotationBringsOtherIdeasToTheTop() {
        let niches: [Niche] = [.lifestyle, .wellness]
        let total = niches.flatMap(ThemeCatalog.ideas(for:)).count
        #expect(ThemeCatalog.page(for: niches, rotation: 2).first == ThemeCatalog.page(for: niches, rotation: 0)[2])
        #expect(ThemeCatalog.page(for: niches, rotation: total) == ThemeCatalog.page(for: niches, rotation: 0))
    }

    @Test func ideaReadsAsAPromptAndAMetaLine() {
        let idea = ThemeCatalog.ideas(for: .finance)[0]
        #expect(idea.prompt == "1 min explainer video: Compound interest, explained simply")
        #expect(idea.meta == "Explainer · ~1 min · Finance")
    }
}
