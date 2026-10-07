//
//  WritingImportViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The creator's way through the import: bring texts, say they are theirs, wait, review.
@MainActor
@Suite("Import my writing · the way through")
struct WritingImportViewModelTests {
    private func model(_ reader: FakeStyleReader = FakeStyleReader()) -> WritingImportViewModel {
        WritingImportViewModel(reader: reader)
    }

    private func waitForReview(_ model: WritingImportViewModel) async {
        for _ in 0..<400 where model.step != .review {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test func pastedTextsAreAddedAndTheBoxIsEmptied() {
        let model = model()
        model.draft = WritingSamples.maya.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        #expect(model.pieces.count == WritingSamples.maya.count)
        #expect(model.draft.isEmpty)
        #expect(model.sources.map(\.count) == [WritingSamples.maya.count])
        #expect(!model.needsMoreForHabits)
    }

    @Test func aPasteWithNothingToReadIsSaidSoAndKept() {
        let model = model()
        model.draft = "hello there"
        model.addDraft(source: "Pasted")
        #expect(model.pieces.isEmpty && model.pasteWasEmpty && model.draft == "hello there")
    }

    @Test func theSameTextPastedAgainIsNotAddedTwice() {
        let model = model()
        for _ in 0..<2 {
            model.draft = WritingSamples.maya[0]
            model.addDraft(source: "Pasted")
        }
        #expect(model.pieces.count == 1)
    }

    @Test func fewTextsAskForMoreToFindHabits() {
        let model = model()
        model.draft = WritingSamples.maya[0]
        model.addDraft(source: "Pasted")
        #expect(model.needsMoreForHabits)
    }

    @Test func nothingIsReadUntilTheCreatorSaysTheyWroteIt() {
        let model = model()
        model.draft = WritingSamples.maya.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        #expect(!model.canRead)
        model.read(against: CreatorProfile())
        #expect(model.step == .collect)
        model.isOwn = true
        #expect(model.canRead)
    }

    @Test func readingEndsInAReviewWithWhatTheModelSaid() async {
        let reader = FakeStyleReader()
        let model = model(reader)
        model.draft = WritingSamples.maya.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        model.isOwn = true
        model.read(against: CreatorProfile())
        #expect(model.step == .reading)
        await waitForReview(model)
        #expect(model.step == .review && model.proposal.usedAppleIntelligence)
        #expect(model.proposal.findings.contains { $0.id == .tones } && model.proposal.findings.contains { $0.id == .sentences })
        #expect(reader.reads == 1)
        #expect(reader.lastSamples.count <= AppleWritingStyleReader.sampleCount + VoiceExcerpt.limit)
        #expect(reader.lastSamples.allSatisfy { $0.count <= VoiceExcerpt.maximumCharacters }, "only excerpts go to the model, never whole texts")
    }

    @Test func withoutAModelTheReviewHasTheMeasuresAlone() async {
        let reader = FakeStyleReader()
        reader.available = false
        let model = model(reader)
        model.draft = WritingSamples.daniel.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        model.isOwn = true
        model.read(against: CreatorProfile())
        await waitForReview(model)
        #expect(!model.proposal.usedAppleIntelligence && reader.reads == 0)
        #expect(!model.proposal.findings.isEmpty && !model.proposal.findings.contains { $0.id == .tones })
    }

    @Test func aModelThatAnswersNothingStillGivesTheMeasures() async {
        let model = model(FakeStyleReader(answer: nil))
        model.draft = WritingSamples.daniel.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        model.isOwn = true
        model.read(against: CreatorProfile())
        await waitForReview(model)
        #expect(model.step == .review && !model.proposal.usedAppleIntelligence && !model.proposal.findings.isEmpty)
    }

    @Test func cancellingWhileTheModelThinksGoesBackToTheTextsAndKeepsThem() async {
        let reader = FakeStyleReader()
        reader.stalls = true
        let model = model(reader)
        model.draft = WritingSamples.maya.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        model.isOwn = true
        model.read(against: CreatorProfile())
        for _ in 0..<200 where model.stage != .askingModel {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(model.stage == .askingModel)
        model.cancelReading()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(model.step == .collect && model.pieces.count == WritingSamples.maya.count)
    }

    @Test func goingBackFromTheReviewKeepsTheTextsAndAFindingCanBeSwitched() async {
        let model = model()
        model.draft = WritingSamples.maya.joined(separator: "\n---\n")
        model.addDraft(source: "Pasted")
        model.isOwn = true
        model.read(against: CreatorProfile())
        await waitForReview(model)
        model.toggle(.energy)
        #expect(model.proposal.findings.first { $0.id == .energy }?.isOn == false)
        model.backToTexts()
        #expect(model.step == .collect && model.pieces.count == WritingSamples.maya.count)
    }

    @Test func aSourceCanBeTakenOut() {
        let model = model()
        model.draft = WritingSamples.maya[0]
        model.addDraft(source: "Pasted")
        model.draft = WritingSamples.daniel[0]
        model.addDraft(source: "Notes")
        model.remove(source: "Pasted")
        #expect(model.sources.map(\.name) == ["Notes"])
    }
}
