//
//  IdeaLanguageDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// Ideas outside English on a real iPhone, the same slots (food, travel, fitness and personal finance, three batches of six) asked three ways:
/// as until 03/11/2026 (`plain`: the iPhone's model, the topic alone); as the app asks them now (`edited`: each around a subject of its topic's
/// ingredients from Private Cloud Compute, `IdeaIngredients`, then edited by it, `IdeaEdits`), printed beside the iPhone's draft of the same
/// idea. Written by Private Cloud Compute itself around the same subjects, they read literally ("Acordo com colega na viagem gera uma ideia."),
/// as on 01/11/2026: that way was measured and left out. What is printed is what the creator would read, one
/// JSON line per brief ("IDEALANG {…}") with whether the card would show it (`IdeaSpecificity`), and the ingredients ("IDEASEED …"), for a native
/// reader to mark: natural, odd (it reads as a translation) or wrong (it isn't grammatical, or means nothing). Opt-in, on a device with Apple
/// Intelligence, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device IdeaLanguageDeviceTests`.
@MainActor
@Suite("Ideas in the creator's language on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct IdeaLanguageDeviceTests {
    enum Way: String, CaseIterable, Sendable {
        case plain, edited
    }

    private let topics: [IdeaTopic] = [Niche.food, .travel, .fitness, .finance].map {
        IdeaTopic(name: $0.promptName, label: $0.label, niche: $0)
    }
    private let batches = 3

    private func ready() throws {
        KeepScreenAwake.enable()
        guard ScriptAIService(usesPrivateCloudCompute: true).availability.onDevice else {
            try Test.cancel("Apple Intelligence isn't available on this device")
        }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
    }

    private struct Line: Encodable {
        let way: String
        let language: String
        let batch: Int
        let seconds: Double
        let model: String
        let edited: Bool
        let topic: String
        let subject: String
        let kind: String
        let title: String
        let angle: String
        let opening: String
        /// The card would show it: none of the weaknesses that make an idea unusable (`IdeaSpecificity.isUnusable`); false for one the editor dropped.
        let shown: Bool
        let weaknesses: [String]
        /// The iPhone's draft of the same idea, before Private Cloud Compute edited it.
        let draftTitle: String
        let draftAngle: String
        let draftOpening: String
    }

    @Test(arguments: [CueLanguage.portugueseBrazil, .spanish, .french, .german, .japanese])
    func ideas(in language: CueLanguage) async throws {
        try ready()
        defer { ScriptAIService.editsIdeas = true }
        print("IDEAQUOTA before \(language.rawValue): \(PrivateCloudComputeLanguageModel().quotaUsage)")
        var ingredients: [IdeaTopic: IdeaIngredients] = [:]
        let cook = ScriptAIService(usesPrivateCloudCompute: true)
        for topic in topics {
            let started = ContinuousClock.now
            do {
                let found = try await cook.ideaIngredients(for: topic, apartFrom: [], creator: nil, language: language)
                ingredients[topic] = found
                let seconds = (started.duration(to: .now).inSeconds * 10).rounded() / 10
                let lists = IdeaIngredientKind.allCases.map { "\($0.rawValue): \(found.subjects($0).joined(separator: " | "))" }
                print("IDEASEED \(language.rawValue) \(topic.name) \(seconds)s — \(lists.joined(separator: " — "))")
            } catch {
                print("IDEASEED-ERROR \(language.rawValue) \(topic.name): \(error)")
            }
        }
        var count = 0
        for way in Way.allCases {
            ScriptAIService.editsIdeas = way == .edited
            let service = ScriptAIService(usesPrivateCloudCompute: true)
            let defaults = TestDefaults()
            defer { defaults.tearDown() }
            let store = IdeaIngredientStore(defaults: defaults.defaults)
            for (topic, found) in ingredients { store.keep(found, for: topic, in: language) }
            for batch in 0..<batches {
                let plain = IdeaTaste().slots(round: batch, among: topics)
                let slots = way == .plain ? plain : store.seasoned(plain, in: language)
                count += try await printBatch(by: service, way: way, slots: slots, language: language, batch: batch)
                try await Task.sleep(for: .seconds(1))
            }
        }
        print("IDEAQUOTA after \(language.rawValue): \(PrivateCloudComputeLanguageModel().quotaUsage)")
        #expect(count >= batches * Way.allCases.count * 3, "Only \(count) ideas came back")
    }

    /// The owner's topics (AI, daily routines, cooking) and scripts lately about all three, asked as the app asks them (ingredients clear of the
    /// other topics, the editor, two ideas of six joining two topics: `IdeaSlot.bridging`, one left open: `IdeaSlot.opening`): one JSON line per
    /// idea ("IDEAMIX {…}", with the topic it joins) for a reader to mark the ones that bring in a topic they weren't joined with. Before
    /// 03/11/2026, 4 in 48 did, all of them daily routines turned into coffee recipes; with ingredients clear of the other topics, 0 in 33.
    @Test func topicsStayApart() async throws {
        try ready()
        let language = CueLanguage.portugueseBrazil
        let mine: [IdeaTopic] = [Niche.tech, .lifestyle, .food].map { IdeaTopic(name: $0.promptName, label: $0.label, niche: $0) }
        let lately = [
            "Como uso o ChatGPT para planejar a semana", "Lasanha de abobrinha em 20 minutos", "Minha rotina antes das 7 da manhã",
            "3 apps de IA que uso todo dia", "O que eu cozinho quando chego cansado",
        ]
        let service = ScriptAIService(usesPrivateCloudCompute: true)
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let store = IdeaIngredientStore(defaults: defaults.defaults)
        for topic in mine {
            let others = mine.filter { $0 != topic }
            if let found = try? await service.ideaIngredients(for: topic, apartFrom: others, creator: nil, language: language) {
                store.keep(found, for: topic, in: language)
                print("IDEASEED \(topic.name): \(IdeaIngredientKind.allCases.map { found.subjects($0).joined(separator: " | ") }.joined(separator: " — "))")
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var count = 0
        for batch in 0..<6 {
            let shaped = IdeaSlot.opening(IdeaSlot.bridging(IdeaTaste().slots(round: batch, among: mine), among: mine, round: batch), round: batch)
            let slots = IdeaSlot.focusing(store.seasoned(shaped, in: language), round: batch)
            let ideas: [ThemeIdea]
            do {
                ideas = try await service.suggestIdeas(slots: slots, language: language, voice: nil, inspiration: lately, priority: .waiting)
            } catch {
                print("IDEAMIX-ERROR batch \(batch): \(error)")
                continue
            }
            for idea in ideas {
                let slot = slots.first { $0.angle.rawValue == idea.brief?.angleKind }
                let line = [
                    "batch": "\(batch)", "topic": slot?.topic.name ?? "", "bridge": slot?.bridge?.name ?? "", "subject": slot?.subject ?? "",
                    "open": "\(slot?.isOpen ?? false)", "title": idea.brief?.subject ?? idea.title, "angle": idea.brief?.angle ?? "",
                    "opening": idea.brief?.openingLine ?? "",
                    "shown": "\(!IdeaSpecificity.isUnusable(idea))",
                ]
                print("IDEAMIX \(String(bytes: try encoder.encode(line), encoding: .utf8) ?? "")")
                count += 1
            }
            try await Task.sleep(for: .seconds(1))
        }
        #expect(count >= 18, "Only \(count) ideas came back")
    }

    /// One batch, printed one JSON line per slot (an idea the editor dropped too); how many ideas came back.
    private func printBatch(by service: ScriptAIService, way: Way, slots: [IdeaSlot], language: CueLanguage, batch: Int) async throws -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let started = ContinuousClock.now
        let ideas: [ThemeIdea]
        do {
            ideas = try await service.suggestIdeas(slots: slots, language: language, voice: nil, inspiration: [], priority: .waiting)
        } catch {
            print("IDEALANG-ERROR \(way.rawValue) \(language.rawValue) batch \(batch): \(error)")
            return 0
        }
        let seconds = (started.duration(to: .now).inSeconds * 10).rounded() / 10
        let drafts = service.lastIdeaDrafts
        for (index, slot) in slots.enumerated() {
            let idea = ideas.first { $0.brief?.angleKind == slot.angle.rawValue }
            let draft = index < drafts.count ? drafts[index] : nil
            let edited = service.lastIdeasEdited
            guard idea != nil || (edited && draft != nil) else { continue }
            let weaknesses = idea.map { IdeaSpecificity.weaknesses(of: $0).map(\.rawValue) } ?? ["dropped"]
            let shownDraft = edited ? draft : nil
            let line = Line(
                way: way.rawValue, language: language.rawValue, batch: batch, seconds: seconds,
                model: service.lastIdeaModel.map { "\($0)" } ?? "", edited: edited, topic: slot.topic.name,
                subject: slot.subject ?? "", kind: slot.angle.rawValue, title: idea.map { $0.brief?.subject ?? $0.title } ?? "",
                angle: idea?.brief?.angle ?? "", opening: idea?.brief?.openingLine ?? "",
                shown: idea.map { !IdeaSpecificity.isUnusable($0) } ?? false, weaknesses: weaknesses,
                draftTitle: shownDraft?.title ?? "", draftAngle: shownDraft?.angle ?? "", draftOpening: shownDraft?.openingLine ?? ""
            )
            print("IDEALANG \(String(bytes: try encoder.encode(line), encoding: .utf8) ?? "")")
        }
        return ideas.count
    }
}
