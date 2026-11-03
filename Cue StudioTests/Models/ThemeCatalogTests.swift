//
//  ThemeCatalogTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ThemeCatalog")
struct ThemeCatalogTests {
    @Test func everyStockedThemeHasSixStartersAndWellnessAndEducationTheirThree() {
        for niche in ThemeCatalog.stocked {
            #expect(ThemeCatalog.written(for: niche).count == 6, "\(niche)")
        }
        #expect(ThemeCatalog.written(for: .wellness).count == 3)
        #expect(ThemeCatalog.written(for: .education).count == 3)
    }

    /// The themes added on 03/11/2026 have no starters of their own yet: theirs are made from the theme's name and subtopics.
    @Test func everyThemeHasStartersAboutItself() {
        for niche in Niche.offered {
            let topic = IdeaTopic(name: niche.promptName, label: niche.label, niche: niche)
            let ideas = ThemeCatalog.ideas(for: topic)
            #expect(ideas.count >= 3, "\(niche)")
            #expect(ideas.allSatisfy { $0.niche == niche && $0.brief?.topic == niche.promptName }, "\(niche)")
        }
    }

    @Test func theLibrarysIdeasComeAfterTheWrittenOnesAndNoneRepeats() {
        for niche in ThemeCatalog.stocked {
            let written = ThemeCatalog.written(for: niche)
            let all = ThemeCatalog.ideas(for: niche)
            #expect(Array(all.prefix(written.count)) == written, "\(niche)")
            #expect(Set(all.map(\.id)).count == all.count, "\(niche)")
            #expect(all.count >= written.count + (IdeaLibrary.current == nil ? 0 : 30), "\(niche): \(all.count)")
        }
    }

    @Test func everyStarterIsAWholeBriefThatFitsTheComposer() {
        for niche in Niche.allCases {
            for idea in ThemeCatalog.written(for: niche) {
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

    @Test func ideaReadsAsAPrompt() {
        let idea = ThemeCatalog.ideas(for: .finance)[0]
        #expect(idea.prompt == "1 min explainer video: Compound interest, explained simply")
    }
}
