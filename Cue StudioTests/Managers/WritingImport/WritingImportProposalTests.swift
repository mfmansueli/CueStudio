//
//  WritingImportProposalTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the creator reviews after importing, and what is saved when they accept.
@MainActor
@Suite("Import my writing · review and save")
struct WritingImportProposalTests {
    private func analysis(_ texts: [String] = WritingSamples.maya) -> WritingAnalysis {
        WritingAnalyzer.analyze(texts.map { WritingPiece(text: $0, source: "Pasted") })
    }

    private func finding(_ kind: WritingFinding.Kind, in proposal: WritingImportProposal) -> WritingFinding? {
        proposal.findings.first { $0.id == kind }
    }

    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    @Test func aCreatorWhoAnsweredNothingGetsEverythingSwitchedOn() {
        let proposal = WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: CreatorProfile())
        #expect(proposal.findings.count >= 6)
        #expect(proposal.findings.allSatisfy { $0.isOn && !$0.replaces })
        #expect(finding(.sentences, in: proposal)?.value == .sentences(.short))
        #expect(finding(.phrases, in: proposal)?.value == .phrases(["Okay, real talk"]))
        #expect(!proposal.usedAppleIntelligence)
        #expect(!proposal.excerpts.isEmpty && proposal.fingerprint != nil)
    }

    @Test func whatTheCreatorAlreadyAnsweredIsNotOverwrittenUnlessTheyChoose() {
        var profile = CreatorProfile()
        profile.style.energy = .calm
        profile.style.sentences = .short
        let proposal = WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: profile)
        let energy = finding(.energy, in: proposal)
        #expect(energy?.replaces == true && energy?.isOn == false, "they said calm, the writing says lively: their word stands until they switch it")
        #expect(finding(.sentences, in: proposal) == nil, "the same answer is not offered again")
    }

    @Test func listsOnlyAddToWhatTheyHoldAndStayWithinTheLimit() {
        var profile = CreatorProfile()
        profile.phrases = ["One", "Two", "Three", "Four"]
        profile.openings = ["Question", "POV"]
        let proposal = WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: profile)
        #expect(finding(.openings, in: proposal) == nil, "both places are taken")
        #expect(finding(.phrases, in: proposal)?.value == .phrases(["Okay, real talk"]), "one place was left")
        profile.phrases = ["Okay, real talk"]
        let again = WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: profile)
        #expect(finding(.phrases, in: again) == nil, "what they already say is not added twice")
    }

    @Test func whatTheModelSaysIsKeptOnlyWhenItIsOnCuesLists() {
        let reading = StyleReading(tones: ["warmCalm", "made-up", "warmCalm"], topics: ["finance", "bogus", "tech"], audience: "professionals", humor: "little")
        let proposal = WritingImportProposalBuilder.build(analysis: analysis(), reading: reading, profile: CreatorProfile())
        #expect(finding(.tones, in: proposal)?.value == .tones([.warmCalm]))
        #expect(finding(.topics, in: proposal)?.value == .topics(["finance", "tech"]))
        #expect(finding(.audience, in: proposal)?.value == .audience(.professionals))
        #expect(finding(.humor, in: proposal)?.value == .humor(.little))
        #expect(proposal.usedAppleIntelligence)
        let unclear = WritingImportProposalBuilder.build(
            analysis: analysis(), reading: StyleReading(tones: [], topics: [], audience: "unclear", humor: "x"), profile: CreatorProfile()
        )
        #expect(finding(.tones, in: unclear) == nil && finding(.audience, in: unclear) == nil && finding(.humor, in: unclear) == nil)
    }

    @Test func topicsFillOnlyTheRoomThatIsLeft() {
        var profile = CreatorProfile()
        profile.niches = [.fitness, .food]
        let reading = StyleReading(tones: [], topics: ["finance", "tech", "travel"], audience: "unclear", humor: "none")
        let proposal = WritingImportProposalBuilder.build(analysis: analysis(), reading: reading, profile: profile)
        #expect(finding(.topics, in: proposal)?.value == .topics(["finance"]))
    }

    @Test func acceptingSavesWhatIsOnAndLeavesWhatIsOff() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let reading = StyleReading(tones: ["energetic"], topics: ["fitness"], audience: "youngAdults", humor: "lot")
        var proposal = WritingImportProposalBuilder.build(analysis: analysis(), reading: reading, profile: service.profile)
        let energy = proposal.findings.firstIndex { $0.id == .energy }!
        proposal.findings[energy].isOn = false
        let applied = service.apply(proposal)
        #expect(applied == proposal.findings.count - 1)
        let profile = service.profile
        #expect(profile.style.sentences == .short && profile.style.energy == nil)
        #expect(profile.sounds == [.energetic] && profile.hasAnswered(.tone))
        #expect(profile.audienceGroup == .youngAdults && profile.hasAnswered(.audience))
        #expect(profile.niches == [.fitness])
        #expect(profile.reach.humor == .lot && profile.reach.length == .under30)
        #expect(profile.speaksAs == .i)
        #expect(profile.phrases == ["Okay, real talk"])
        #expect(profile.openings.count == 2 && profile.endings.count == 2)
        #expect(profile.openings.contains(VoiceChoiceCatalog.openingLabel("Question")))
        #expect(profile.excerpts == proposal.excerpts.prefix(VoiceExcerpt.limit).map { $0 })
        #expect(profile.fingerprint == proposal.fingerprint)
    }

    @Test func importingTheSameWritingTwiceChangesNothingTheSecondTime() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let first = WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: service.profile)
        service.apply(first)
        let kept = service.profile
        let second = WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: service.profile)
        service.apply(second)
        #expect(second.findings.isEmpty, "everything it found is already there")
        #expect(service.profile.phrases == kept.phrases && service.profile.openings == kept.openings)
        #expect(service.profile.excerpts.count == kept.excerpts.count)
    }

    @Test func aSecondImportAddsItsExcerptsFirstAndKeepsTheLibraryWithinItsSize() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.apply(WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: service.profile))
        let before = service.profile.excerpts
        service.apply(WritingImportProposalBuilder.build(analysis: analysis(WritingSamples.daniel), reading: nil, profile: service.profile))
        let after = service.profile.excerpts
        #expect(after.count <= VoiceExcerpt.limit && after.count > before.count)
        #expect(after.first?.text != before.first?.text)
        #expect(Set(after.map(\.id)).isSuperset(of: Set(before.map(\.id)).prefix(3)))
    }

    @Test func forgettingTheImportKeepsTheAnswersThatCameFromIt() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.apply(WritingImportProposalBuilder.build(analysis: analysis(), reading: nil, profile: service.profile))
        service.clearImportedWriting()
        #expect(service.profile.excerpts.isEmpty && service.profile.fingerprint == nil)
        #expect(service.profile.style.sentences == .short)
    }

    @Test func nothingFoundIsNothingToSave() {
        let proposal = WritingImportProposalBuilder.build(analysis: WritingAnalysis(), reading: nil, profile: CreatorProfile())
        #expect(!proposal.hasAnything && proposal.findings.isEmpty)
    }
}
