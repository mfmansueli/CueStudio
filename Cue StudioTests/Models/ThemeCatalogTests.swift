//
//  ThemeCatalogTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ThemeCatalog")
struct ThemeCatalogTests {
    @Test func everyNicheHasThreeStarterIdeas() {
        for niche in Niche.allCases {
            #expect(ThemeCatalog.ideas(for: niche).count == 3)
        }
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
        #expect(ThemeCatalog.page(for: niches, rotation: 2).first == ThemeCatalog.page(for: niches, rotation: 0)[2])
        #expect(ThemeCatalog.page(for: niches, rotation: 6) == ThemeCatalog.page(for: niches, rotation: 0))
    }

    @Test func ideaReadsAsAPromptAndAMetaLine() {
        let idea = ThemeCatalog.ideas(for: .finance)[0]
        #expect(idea.prompt == "1 min explainer video: Compound interest, explained simply")
        #expect(idea.meta == "Explainer · ~1 min · Finance")
    }
}
