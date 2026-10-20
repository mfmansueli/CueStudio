//
//  ScriptTextViewTests.swift
//  Cue StudioTests
//

import Testing
import UIKit
@testable import Cue_Studio

/// The script page's text view: cues drawn as chips while the words stay the page's text, deleting into a cue taking all of it, and
/// changes from outside kept in the undo history while the creator edits.
@MainActor
@Suite("ScriptTextView")
struct ScriptTextViewTests {
    private func makeView(_ text: String, showsCues: Bool = true, passage: Range<Int>? = nil) -> ScriptTextView {
        let view = ScriptTextView(style: ScriptTextStyle(size: 19, passage: passage, showsCues: showsCues))
        view.frame = CGRect(x: 0, y: 0, width: 360, height: 600)
        view.show(text)
        return view
    }

    private func chip(at offset: Int, in view: ScriptTextView) -> TextChipBox? {
        view.textStorage.attribute(TextChipAttribute.nsKey, at: offset, effectiveRange: nil) as? TextChipBox
    }

    private func color(at offset: Int, in view: ScriptTextView) -> UIColor? {
        view.textStorage.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor
    }

    @Test func cuesAreChipsAndTheWordsStayTheText() throws {
        let text = "Hi 😀 [pause] there [laugh]"
        let view = makeView(text)
        #expect(view.textStorage.string == text)
        #expect(view.textLayoutManager != nil, "TextKit 2, or the chips aren't drawn")
        let pause = (text as NSString).range(of: "[pause]")
        let box = try #require(chip(at: pause.location, in: view))
        #expect(box.chip.symbol == "pause.fill")
        #expect(chip(at: NSMaxRange(pause) - 1, in: view) === box, "one chip from bracket to bracket")
        #expect(chip(at: pause.location - 1, in: view) == nil)
        // The brackets are hidden; the first one makes room for the symbol.
        #expect(color(at: pause.location, in: view) == .clear)
        #expect(color(at: NSMaxRange(pause) - 1, in: view) == .clear)
        let kern = try #require(view.textStorage.attribute(.kern, at: pause.location, effectiveRange: nil) as? CGFloat)
        #expect(kern > box.metrics.inset)
        // The creator's own cue: a chip without a symbol.
        let laugh = (text as NSString).range(of: "[laugh]")
        #expect(try #require(chip(at: laugh.location, in: view)).chip.symbol == nil)
        #expect(chip(at: laugh.location, in: view) !== box)
    }

    @Test func hiddenCuesStayInTheTextWithoutAChip() {
        let view = makeView("Hi [smile] there", showsCues: false)
        #expect(view.textStorage.string == "Hi [smile] there")
        #expect(chip(at: 3, in: view) == nil)
        #expect(color(at: 5, in: view) == .clear)
        view.style.showsCues = true
        #expect(chip(at: 3, in: view) != nil, "switching Cues on paints them again")
    }

    @Test func theAIsPassageIsPaintedButItsCuesStayChips() {
        let view = makeView("Keep [pause] this", passage: 0..<17)
        #expect(view.textStorage.attribute(.backgroundColor, at: 0, effectiveRange: nil) != nil)
        #expect(view.textStorage.attribute(.backgroundColor, at: 6, effectiveRange: nil) == nil)
        #expect(chip(at: 5, in: view) != nil)
    }

    /// Backspace on "]" (or any deletion that cuts into a cue) takes the whole cue and the space it would leave doubled.
    @Test func deletingIntoACueTakesAllOfIt() {
        let view = makeView("😀 Hi [smile] there")
        #expect(view.cueDeletion(replacing: NSRange(location: 12, length: 1), with: "") == NSRange(location: 6, length: 8))
        #expect(view.cueDeletion(replacing: NSRange(location: 4, length: 1), with: "") == nil, "a plain letter")
        #expect(view.cueDeletion(replacing: NSRange(location: 12, length: 1), with: "x") == nil, "typing over isn't deleting")
    }

    @Test func theSelectionIsInCharacters() {
        let view = makeView("😀 [pause] go")
        view.select(characters: 2..<9)
        #expect(view.selectedRange == NSRange(location: 3, length: 7))
        #expect(view.characterSelection == 2..<9)
    }

    /// While the creator edits, a cue from the bar (or any change from the page) is one step the keyboard's undo takes back; so is a
    /// whole cue deleted at once.
    @Test func changesWhileEditingCanBeUndone() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        let view = makeView("Talk more")
        window.addSubview(view)
        window.isHidden = false
        #expect(view.becomeFirstResponder())
        let manager = try #require(view.undoManager)
        manager.removeAllActions()

        view.replace(with: "Talk [pause] more")
        #expect(view.textStorage.string == "Talk [pause] more")
        #expect(chip(at: 5, in: view) != nil, "the new cue is painted")
        await Wait.until { manager.canUndo && manager.groupingLevel == 0 }
        manager.undo()
        #expect(view.textStorage.string == "Talk more")

        view.replace(with: "Talk [pause] more")
        // Each edit is its own step once the run loop closes its group (the creator's taps are separate events).
        await Wait.until { manager.canUndo && manager.groupingLevel == 0 }
        view.delete(NSRange(location: 5, length: 8))
        #expect(view.textStorage.string == "Talk more")
        await Wait.until { manager.canUndo && manager.groupingLevel == 0 }
        manager.undo()
        #expect(view.textStorage.string == "Talk [pause] more")
        view.resignFirstResponder()
    }
}
