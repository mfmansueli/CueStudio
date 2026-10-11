//
//  DraftLearningTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Cue learns from what the creator does with its drafts: how much of a draft they changed (`DraftEdits`), and the service that keeps
/// Cue's drafts and turns a recorded script the creator made their own into an example, with Undo, once per draft.
@MainActor
@Suite("Draft learning")
struct DraftLearningTests {
    private let draft = """
        [smile] Okay, real talk. Mornings are hard for everybody, and I used to fight mine every single day.

        Here is the one change that made my mornings easier: I put my phone in another room before bed. [pause]

        Try it tonight and tell me how tomorrow goes.
        """

    /// The same script, rewritten in the creator's own words.
    private let theirs = """
        [smile] Real talk, I'm not a morning person. For years I hit snooze four times and hated the first hour of my day.

        What finally worked was boring: the phone sleeps in the kitchen now, not next to me. [pause]

        Try it tonight and tell me how tomorrow goes.
        """

    // MARK: - How much changed

    @Test func aDraftRecordedAsCueWroteItIsNotTheCreatorsYet() {
        #expect(DraftEdits.changed(from: draft, to: draft).changed == 0)
        #expect(!DraftEdits.isTheirs(draft: draft, final: draft))
    }

    @Test func aFixedTypoOrASwappedWordIsNotEnough() {
        let touched = draft.replacingOccurrences(of: "every single day", with: "every day")
            .replacingOccurrences(of: "easier", with: "simpler")
        #expect(!DraftEdits.isTheirs(draft: draft, final: touched))
    }

    @Test func aScriptRewrittenInTheirWordsIsTheirs() {
        let (changed, total) = DraftEdits.changed(from: draft, to: theirs)
        #expect(changed >= DraftEdits.minimumChangedWords)
        #expect(Double(changed) / Double(total) >= DraftEdits.learningShare)
        #expect(DraftEdits.isTheirs(draft: draft, final: theirs))
    }

    @Test func cuesCaseAndPunctuationDontCountAsChanges() {
        let restyled = draft.replacingOccurrences(of: "[smile] ", with: "").replacingOccurrences(of: "[pause]", with: "")
            .uppercased().replacingOccurrences(of: ",", with: "")
        #expect(DraftEdits.changed(from: draft, to: restyled).changed == 0)
    }

    @Test func movingSentencesAroundCountsAsChanging() {
        let paragraphs = draft.components(separatedBy: "\n\n")
        let moved = [paragraphs[2], paragraphs[0], paragraphs[1]].joined(separator: "\n\n")
        #expect(DraftEdits.changed(from: draft, to: moved).changed > 0)
    }

    // MARK: - The service

    private func makeService() -> (DraftLearningService, CreatorProfileService, ToastService, TestDefaults) {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let toast = ToastService()
        return (DraftLearningService(profile: profile, toast: toast, defaults: defaults.defaults), profile, toast, defaults)
    }

    private func script(id: UUID, text: String) -> Script {
        Script(id: id, title: "Mornings", text: text, platform: .tiktok)
    }

    @Test func aRecordedScriptTheCreatorMadeTheirOwnBecomesAnExampleWithUndo() {
        let (service, profile, toast, defaults) = makeService()
        defer { defaults.tearDown() }
        let id = UUID()
        service.noteDraft(draft, for: id)
        #expect(service.isCueDraft(id))
        service.tookTake(of: script(id: id, text: theirs))
        let example = profile.profile.approvedSamples.last
        #expect(example?.source == "Your edits")
        #expect(example?.text.hasPrefix("Real talk, I'm not a morning person.") == true)
        #expect(profile.profile.approvals == 0, "it isn't an approval of Cue's words")
        #expect(toast.message == "Cue learned from this")
        #expect(toast.action?.title == "Undo")
        #expect(!service.isCueDraft(id), "each draft teaches once")
        toast.action?.perform()
        #expect(profile.profile.approvedSamples.isEmpty, "Undo takes it back")
    }

    @Test func aDraftRecordedAsItWasWaitsAndTeachesNothing() {
        let (service, profile, toast, defaults) = makeService()
        defer { defaults.tearDown() }
        let id = UUID()
        service.noteDraft(draft, for: id)
        service.tookTake(of: script(id: id, text: draft))
        #expect(profile.profile.approvedSamples.isEmpty)
        #expect(toast.message == nil)
        #expect(service.isCueDraft(id), "they may change it and record again")
    }

    @Test func aScriptCueNeverDraftedTeachesNothing() {
        let (service, profile, _, defaults) = makeService()
        defer { defaults.tearDown() }
        service.tookTake(of: script(id: UUID(), text: theirs))
        service.tookTake(of: nil)
        #expect(profile.profile.approvedSamples.isEmpty)
    }

    @Test func draftsAreKeptAcrossLaunchesAndForgottenWithTheData() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let id = UUID()
        DraftLearningService(profile: profile, toast: ToastService(), defaults: defaults.defaults).noteDraft(draft, for: id)
        let again = DraftLearningService(profile: profile, toast: ToastService(), defaults: defaults.defaults)
        #expect(again.isCueDraft(id))
        again.clear()
        #expect(!DraftLearningService(profile: profile, toast: ToastService(), defaults: defaults.defaults).isCueDraft(id))
    }

    @Test func onlyTheLastDraftsAreKept() {
        let (service, _, _, defaults) = makeService()
        defer { defaults.tearDown() }
        let first = UUID()
        service.noteDraft(draft, for: first)
        for _ in 0..<DraftLearningService.keptDrafts { service.noteDraft(draft, for: UUID()) }
        #expect(service.drafts.count == DraftLearningService.keptDrafts)
        #expect(!service.isCueDraft(first))
    }
}
