//
//  AdBriefKeptTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// A sponsored ad keeps the brand brief it was asked with (`Script.brand`): a draft opened to write by hand has it, and every tool that edits the
/// ad later (rewrites, hooks, a platform version, a translation, Ultra's fit) is told the disclosure, what the ad must and must never say, the
/// link and the code (`reports/entradas-do-criador-2026-11-01-completo.md` §11, A3).
@MainActor
@Suite("Sponsored ad · the brief is kept")
struct AdBriefKeptTests {
    private static let brief = BrandBrief(
        name: "Lumen", product: "Lumen sleep mask", mustSay: "Blocks 100% of light", neverSay: "cures insomnia", link: "lumen.co/cue", code: "CUE15"
    )

    // MARK: - On the script

    @Test func theBriefIsSavedWithTheScriptAndReadBack() throws {
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let script = library.create(title: "", text: "", platform: .tiktok, type: .ad, brand: Self.brief)
        #expect(library.script(id: script.id)?.brand == Self.brief)
        let decoded = try JSONDecoder().decode(Script.self, from: JSONEncoder().encode(script))
        #expect(decoded.brand == Self.brief)
        let older = try JSONDecoder().decode(Script.self, from: JSONEncoder().encode(TestData.script()))
        #expect(older.brand == nil, "a script saved before the brief was kept opens without one")
    }

    @Test func startingAnAdFromAFormatKeepsTheBriefTyped() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let starter = ScriptStarter(
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            languages: TestData.languages(defaults: defaults.defaults), presentation: PresentationService(), ideaDraft: IdeaDraftService(),
            transition: IdeaTransitionService(), writer: FakeScriptWriter(), toast: ToastService()
        )
        let ad = starter.startFromFormat(.type(.ad), brand: Self.brief)
        #expect(library.script(id: ad)?.brand == Self.brief, "the brief the creator typed is what the draft keeps, saved or not")
        let other = starter.startFromFormat(.type(.tutorial), brand: Self.brief)
        #expect(library.script(id: other)?.brand == nil, "only an ad keeps a brand brief")
    }

    @Test func anAdWrittenByAppleIntelligenceKeepsTheBrief() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let ideaDraft = IdeaDraftService()
        let transition = IdeaTransitionService()
        transition.speed = 0.001
        let starter = ScriptStarter(
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            languages: TestData.languages(defaults: defaults.defaults), presentation: PresentationService(), ideaDraft: ideaDraft,
            transition: transition, writer: FakeScriptWriter(), toast: ToastService()
        )
        ideaDraft.formatChoice = .type(.ad)
        ideaDraft.brand = Self.brief
        let id = starter.write(idea: "A sponsored ad for the Lumen sleep mask", fromDock: true, from: .zero)
        #expect(id.flatMap(library.script(id:))?.brand == Self.brief)
    }

    // MARK: - The tools

    private func page(type: ScriptType?) -> (ScriptDetailViewModel, FakeScriptWriter, ScriptLibraryService, TestDefaults) {
        let defaults = TestDefaults()
        var script = TestData.script(text: "This mask changed my nights. #ad\n\nIt blocks 100% of light.\n\nUse CUE15 at lumen.co/cue.", type: type)
        script.brand = Self.brief
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: []))
        takes.load()
        let writer = FakeScriptWriter()
        let viewModel = ScriptDetailViewModel(
            scriptID: script.id, startsEditing: false, revealPause: .zero, library: library, takes: takes,
            preferences: PreferencesService(defaults: defaults.defaults), profile: CreatorProfileService(defaults: defaults.defaults),
            rules: TestData.rulesService(), writer: writer, toast: ToastService()
        )
        return (viewModel, writer, library, defaults)
    }

    @Test func aRewriteOfTheAdIsAskedWithItsBrief() async {
        let (viewModel, writer, _, defaults) = page(type: .ad)
        defer { defaults.tearDown() }
        await viewModel.run(.shorterAndDirect)
        #expect(writer.lastRewrite?.context.brand == Self.brief)
    }

    @Test func aScriptThatIsNoLongerAnAdIsRewrittenAsWhatItIs() async {
        let (viewModel, writer, _, defaults) = page(type: .tutorial)
        defer { defaults.tearDown() }
        await viewModel.run(.shorterAndDirect)
        #expect(writer.lastRewrite != nil && writer.lastRewrite?.context.brand == nil)
    }

    @Test func whatTheToolsAreToldKeepsEveryPartOfTheBrief() {
        let instructions = ScriptPromptBuilder.rewriteInstructions(brand: Self.brief)
        for part in ["#ad", "Lumen sleep mask", "Blocks 100% of light", "Never say or mention: cures insomnia", "lumen.co/cue, CUE15"] {
            #expect(instructions.contains(part), "the tools aren't told “\(part)”: \(instructions)")
        }
        #expect(!ScriptPromptBuilder.rewriteInstructions().contains("#ad"), "a script that isn't an ad is told nothing of brands")
    }

    @Test func newHooksForTheAdPromiseNothingTheBrandDidNotApprove() {
        var context = RewriteContext(structure: .generic, platform: .tiktok, idealRange: 30...60)
        #expect(!ScriptPromptBuilder.hooksPrompt(for: "Hook.\n\nBody.", context: context).contains("sponsored ad"))
        context.brand = Self.brief
        let prompt = ScriptPromptBuilder.hooksPrompt(for: "Hook.\n\nBody.", context: context)
        #expect(prompt.contains("sponsored ad for Lumen") && prompt.contains("cures insomnia"), "\(prompt)")
    }

    @Test func theLinkAndTheCodeAreLeftAsTheyAreEvenInATranslation() {
        let rewrite = ScriptPromptBuilder.preserved(inRewriteOf: "Text.", tool: .shorterAndDirect, voice: nil, brand: Self.brief)
        let translation = ScriptPromptBuilder.preserved(inRewriteOf: "Text.", tool: .translate, voice: nil, brand: Self.brief)
        #expect(rewrite.contains("lumen.co/cue") && rewrite.contains("CUE15"))
        #expect(translation == ["lumen.co/cue", "CUE15"])
    }

    @Test func ultrasFitOfAnAdKeepsTheBrief() {
        var fit = UltraFitRequest(script: "Long ad. #ad", platform: .tiktok, range: 30...60)
        #expect(!fit.stage.prompt.contains("#ad)"))
        fit.brand = Self.brief
        #expect(fit.stage.prompt.contains("Keep the paid partnership disclosure (#ad)") && fit.stage.prompt.contains("CUE15"))
    }
}
