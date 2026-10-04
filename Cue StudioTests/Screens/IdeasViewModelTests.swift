//
//  IdeasViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Need an idea?": ideas for the creator's topics.
@MainActor
@Suite("Ideas")
struct IdeasViewModelTests {
    private func makeViewModel(niches: [Niche] = [.tech], defaults: TestDefaults) -> (IdeasViewModel, FakeScriptWriter) {
        let writer = FakeScriptWriter()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.niches = niches
        return (IdeasViewModel(writer: writer, profile: profile, toast: ToastService(), interfaceLanguage: .english), writer)
    }

    @Test func itStartsWithTheStarterIdeasForTheCreatorsTopics() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (viewModel, _) = makeViewModel(defaults: defaults)
        #expect(!viewModel.ideas.isEmpty && viewModel.ideas.count <= ThemeCatalog.pageSize)
        #expect(viewModel.ideas.allSatisfy { $0.niche == .tech })
        #expect(viewModel.topics == [.tech])
    }

    @Test func withoutTopicsItStartsWithLifestyle() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (viewModel, _) = makeViewModel(niches: [], defaults: defaults)
        #expect(viewModel.topics == [.lifestyle])
        #expect(viewModel.ideas.allSatisfy { $0.niche == .lifestyle })
    }

    @Test func pickingATopicShowsOnlyItsIdeas() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (viewModel, _) = makeViewModel(niches: [.tech, .food], defaults: defaults)
        viewModel.topic = .food
        #expect(!viewModel.ideas.isEmpty && viewModel.ideas.allSatisfy { $0.niche == .food })
        viewModel.topic = nil
        #expect(Set(viewModel.ideas.map(\.niche)) == [.tech, .food])
    }

    @Test func moreIdeasComeFromTheModelOrRotateTheStarters() async {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (viewModel, writer) = makeViewModel(defaults: defaults)
        writer.ideas = [ThemeIdea(title: "From the model", kind: "List", length: .minute1, niche: .tech)]
        await viewModel.loadNewIdeas()
        #expect(viewModel.ideas.map(\.title) == ["From the model"])
        writer.isAvailable = false
        let before = viewModel.ideas
        await viewModel.loadNewIdeas()
        #expect(viewModel.ideas != before && !viewModel.canWrite)
    }
}
