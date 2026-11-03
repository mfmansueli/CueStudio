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

    /// The page sizes the editor from its own layout as the creator types (`fittingHeight`): it must say what a full measure says, for
    /// one line, many, a final empty line, cues and nothing at all.
    @Test(arguments: [
        "", "One line.", "Hi [pause] there [laugh] and on", "A paragraph.\n\nAnother one, longer, that wraps over the width of the page.",
        "Ends with a return.\n", String(repeating: "A long script that goes on and on. [pause] ", count: 120), SampleAIDraft.text,
    ])
    func itsOwnLayoutGivesTheFullMeasure(_ text: String) {
        let view = makeView(text)
        view.frame.size.height = 5_000
        view.layoutIfNeeded()
        let full = view.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)).height
        #expect(abs(view.fittingHeight(for: 360) - full) <= 1, "\(view.fittingHeight(for: 360)) vs \(full)")
    }

    /// While the creator types in one paragraph, the height is that paragraph laid out again plus the words below it (`fittingHeight`):
    /// after letters, words deleted and a cue in one paragraph, another paragraph, a return, a change that didn't say so first and typing
    /// after a final return, it still says what a full measure says.
    @Test func typingKeepsTheFullMeasure() {
        let paragraph = String(repeating: "A long script that goes on and on. [pause] ", count: 30)
        let view = makeView([paragraph, paragraph, paragraph].joined(separator: "\n\n"))
        view.frame.size.height = 5_000
        view.layoutIfNeeded()
        _ = view.fittingHeight(for: 360)
        let second = paragraph.utf16.count + 2
        // The second paragraph first, so the first one's edits don't move it.
        let edits = [
            TypedEdit(at: second + 40, text: " typed in the second paragraph", fromParagraph: false),
            TypedEdit(at: second + 50, text: " and on in it", fromParagraph: true),
            TypedEdit(at: second + 60, text: "\n\nA return makes a new paragraph", fromParagraph: false),
            TypedEdit(at: 100, text: " and a few more words that make the line wrap", fromParagraph: false),
            TypedEdit(at: 150, text: " and more, and more, and more words again and again", fromParagraph: true),
            TypedEdit(at: 120, length: 30, text: "", fromParagraph: true),
            TypedEdit(at: 130, text: "[laugh]", fromParagraph: true),
            TypedEdit(at: 20, text: " set from outside", announced: false, fromParagraph: false),
        ]
        for edit in edits {
            type(edit.text, at: edit.at, replacing: edit.length, into: view, announced: edit.announced)
            #expect(view.measuresTypedParagraph == edit.fromParagraph, "\(edit.text)")
            expectFullMeasure(of: view, after: edit.text)
        }
        // A final return, then letters on the empty line it makes.
        let end = view.textStorage.length
        type("\n", at: end, into: view)
        expectFullMeasure(of: view, after: "a final return")
        type("N", at: end + 1, into: view)
        expectFullMeasure(of: view, after: "a letter after the final return")
        type("ew", at: end + 2, into: view)
        #expect(view.measuresTypedParagraph)
        expectFullMeasure(of: view, after: "letters after the final return")
    }

    /// An edit in `typingKeepsTheFullMeasure`: where, how many letters it replaces, with what, whether it is said first as the keyboard
    /// does, and whether the height is then measured from its paragraph.
    private struct TypedEdit {
        var at: Int
        var length = 0
        var text: String
        var announced = true
        var fromParagraph: Bool
    }

    /// A change as the keyboard makes it: said first (`willEdit`), then made.
    private func type(_ text: String, at location: Int, replacing length: Int = 0, into view: ScriptTextView, announced: Bool = true) {
        let range = NSRange(location: location, length: length)
        if announced { view.willEdit([range], with: text) }
        view.selectedRange = range
        if text.isEmpty { view.deleteBackward() } else { view.insertText(text) }
    }

    /// The height right after a change says what a full measure says; then it is measured as the page would go on measuring it.
    private func expectFullMeasure(of view: ScriptTextView, after change: String) {
        let typed = view.fittingHeight(for: 360)
        let full = view.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)).height
        #expect(abs(typed - full) <= 1, "after \(change): \(typed) vs \(full)")
        _ = view.fittingHeight(for: 360)
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
