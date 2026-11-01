//
//  ScriptHookTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The hook the tip times, "3 new hooks" replaces and "✦ Shape" pauses after (`ScriptHook`), on the scripts creators have.
@Suite("ScriptHook")
struct ScriptHookTests {
    /// Apple Intelligence's hook block: the first paragraph, short, is the hook whole.
    @Test func aShortFirstParagraphIsTheHookWhole() {
        let text = "Okay, real talk. [pause] Three tiny habits changed my mornings.\n\nFirst, water before the phone."
        #expect(ScriptHook.text(of: text) == "Okay, real talk. [pause] Three tiny habits changed my mornings.")
    }

    /// Ultra AI's first paragraph of three sentences: only the opening question is the hook, and the rest of the paragraph stays.
    @Test func aLongFirstParagraphOpensWithItsFirstSentence() {
        let text = """
        Are you working out at home but seeing zero results? You do not need a large gym setup to get fit. But I see the same three mistakes \
        ruin home workouts every single day, and today we fix all of them.

        First up, the random workout trap.
        """
        #expect(ScriptHook.text(of: text) == "Are you working out at home but seeing zero results?")
        let replaced = ScriptHook.replacing(in: text, with: "Home workouts not working?")
        #expect(replaced.hasPrefix("Home workouts not working? You do not need a large gym setup to get fit."))
        #expect(replaced.hasSuffix("First up, the random workout trap."))
    }

    /// A script written in one block keeps everything after its first sentence when a hook is picked.
    @Test func aScriptInOneBlockLosesNothingButItsHook() {
        let text = "Gente, hoje eu quero mostrar como eu organizo meu domingo pra semana não virar um caos. [pause] Primeiro eu faço uma lista "
            + "rápida de tudo que tá na minha cabeça, tudo mesmo. Depois eu separo o que é dessa semana e o que pode esperar, e só."
        let replaced = ScriptHook.replacing(in: text, with: "Seu domingo decide a sua semana.")
        #expect(replaced.hasPrefix("Seu domingo decide a sua semana. [pause] Primeiro eu faço uma lista"))
        #expect(replaced.hasSuffix("e o que pode esperar, e só."))
    }

    /// "Okay." alone isn't a hook: it is said with the sentence after it.
    @Test func aWordOrTwoIsSaidWithTheNextSentence() {
        let text = "Okay. Nobody tells you this about cold showers, and I wish someone had told me before my first week of trying them. "
            + "The first three days are the hardest part, and after that something changes in how you start the morning."
        #expect(ScriptHook.text(of: text).hasPrefix("Okay. Nobody tells you this about cold showers"))
        #expect(ScriptHook.text(of: text).hasSuffix("first week of trying them."))
    }

    /// The cues around the hook stay where they were; only its words change.
    @Test func theCuesAroundTheHookStay() {
        let text = "[look at camera] I quit sugar for a month. [pause]\n\nHere is what happened."
        #expect(ScriptHook.text(of: text) == "I quit sugar for a month.")
        #expect(ScriptHook.replacing(in: text, with: "A month without sugar.") == "[look at camera] A month without sugar. [pause]\n\nHere is what happened.")
    }

    /// A disclosure up front is never taken for the hook, nor replaced by one.
    @Test func theDisclosureIsNotTheHook() {
        let text = ScriptTextEditing.disclosureLine(in: .english) + "\n\nThis planner saved my week.\n\nHere is how."
        #expect(ScriptHook.text(of: text) == "This planner saved my week.")
        let replaced = ScriptHook.replacing(in: text, with: "My week, fixed.")
        #expect(replaced.hasPrefix(ScriptTextEditing.disclosureLine(in: .english) + "\n\nMy week, fixed."))
    }

    @Test func anEmptyScriptHasNoHookAndTakesTheNewOne() {
        #expect(ScriptHook.text(of: " \n ").isEmpty)
        #expect(ScriptHook.replacing(in: "  ", with: "Hook.") == "Hook.")
    }

    /// The tip times the hook, not the whole first paragraph: Ultra's opening question is a few seconds, not twenty.
    @Test func theTipTimesTheHookNotTheParagraph() {
        let text = "Are you working out at home but seeing zero results? " + TestData.words(50) + ".\n\nBody."
        let overrun = ScriptBlocks.hookOverrun(in: text, structure: .generic)
        #expect(overrun.map { $0 < 5 } ?? true, "The tip says the hook runs \(overrun ?? 0) s")
    }
}
