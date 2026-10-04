//
//  PrompterSectionsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The sections the prompter's rail and label follow while the creator reads.
@MainActor
@Suite("Prompter sections")
struct PrompterSectionsTests {
    private let text = "Hook line.\n\nBody one.\n\nBody two.\n\nFollow me for more."

    @Test func aTalkingVideoHasAHookABodyAndACTA() {
        let sections = PrompterSections(text: text, structure: .generic, speed: 0.7)
        #expect(sections.markers.map(\.firstParagraph) == [0, 1, 3])
        #expect(sections.isMeaningful)
    }

    @Test func theSectionFollowsTheParagraphBeingRead() {
        let sections = PrompterSections(text: text, structure: .generic, speed: 0.7)
        #expect([0, 1, 2, 3].map { sections.index(atParagraph: $0) } == [0, 1, 1, 2])
        #expect(sections.index(atParagraph: 99) == 2)
    }

    @Test func theLabelSaysWhereYouAreInTheScript() {
        let sections = PrompterSections(markers: [
            .init(label: "Hook", firstParagraph: 0), .init(label: "Body", firstParagraph: 1), .init(label: "CTA", firstParagraph: 3),
        ])
        #expect(sections.title(at: 0).hasPrefix("HOOK") && sections.title(at: 0).contains("1"))
        #expect(sections.title(at: 1).hasPrefix("BODY"))
        #expect(sections.title(at: 5) == "")
    }

    @Test func aScriptOfOneParagraphNeedsNoRail() {
        let one = PrompterSections(text: "Just one paragraph.", structure: .generic, speed: 0.7)
        #expect(!one.isMeaningful)
        #expect(!PrompterSections(markers: []).isMeaningful)
    }

    @Test func aMissingCTAIsNotAStar() {
        let sections = PrompterSections(text: "Hook.\n\nBody only here.", structure: .generic, speed: 0.7)
        #expect(sections.markers.allSatisfy { $0.firstParagraph < 2 })
    }

    @Test func theStarsSitEvenlyAlongTheRail() {
        #expect(SectionRail.position(of: 0, of: 3) == 0)
        #expect(SectionRail.position(of: 1, of: 3) == 0.5)
        #expect(SectionRail.position(of: 2, of: 3) == 1)
        #expect(SectionRail.position(of: 0, of: 1) == 0)
    }

    @Test func theCountdownOpacityOfAHorizonSpeckRisesThenFades() {
        #expect(HorizonParticles.opacity(at: 0) == 0)
        #expect(abs(HorizonParticles.opacity(at: 0.2) - 0.9) < 0.0001)
        #expect(abs(HorizonParticles.opacity(at: 1) - 0) < 0.0001)
    }
}
