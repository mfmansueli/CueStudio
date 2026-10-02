//
//  ScriptParagraphs.swift
//  Cue Studio
//

import Foundation

/// The script as the editor holds it: one entry per paragraph (a line of the text), with room for
/// an empty one while the creator is about to type in it. Pure, so splitting at the caret, merging
/// and the offsets that follow are tested without a screen.
nonisolated enum ScriptParagraphs {
    /// Where the caret goes after an edit: a paragraph and a UTF-16 offset in it (what `NSRange`
    /// speaks).
    struct Caret: Equatable, Sendable {
        var index: Int
        var offset: Int
    }

    struct Edit: Equatable, Sendable {
        var paragraphs: [String]
        var caret: Caret
    }

    /// The paragraphs of `text`, never none: an empty script is one empty paragraph to write in.
    static func split(_ text: String) -> [String] {
        let paragraphs = CueParser.paragraphs(in: text)
        return paragraphs.isEmpty ? [""] : paragraphs
    }

    /// The text to save: the paragraphs that say something, trimmed, a blank line between them.
    static func join(_ paragraphs: [String]) -> String {
        paragraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Paragraph `index` became `newText`, which may now have line breaks (Return, or a paste):
    /// each line is its own paragraph. `caret` is where the finger was in `newText`, and the
    /// caret follows it to the right line.
    static func replacing(
        paragraphAt index: Int, with newText: String, caret: Int, in paragraphs: [String]
    ) -> Edit {
        guard paragraphs.indices.contains(index) else { return Edit(paragraphs: paragraphs, caret: Caret(index: index, offset: caret)) }
        let lines = newText.components(separatedBy: .newlines)
        var result = paragraphs
        result.replaceSubrange(index...index, with: lines)
        // The line the caret is on, and how far along it.
        var remaining = max(0, caret)
        var line = 0
        for (position, text) in lines.enumerated() {
            let length = text.utf16.count
            if remaining <= length || position == lines.count - 1 {
                line = position
                remaining = min(remaining, length)
                break
            }
            remaining -= length + 1
        }
        return Edit(paragraphs: result, caret: Caret(index: index + line, offset: remaining))
    }

    /// Backspace at the start of paragraph `index`: it joins the one before (a space between them
    /// when both say something), and the caret lands at the seam. The first paragraph has nothing
    /// before it.
    static func mergingWithPrevious(_ index: Int, in paragraphs: [String]) -> Edit? {
        guard index > 0, paragraphs.indices.contains(index) else { return nil }
        let previous = paragraphs[index - 1]
        let current = paragraphs[index]
        let separator = !previous.isEmpty && !current.isEmpty ? " " : ""
        var result = paragraphs
        result.replaceSubrange((index - 1)...index, with: [previous + separator + current])
        return Edit(paragraphs: result, caret: Caret(index: index - 1, offset: (previous + separator).utf16.count))
    }

    /// `text` typed at `range` of paragraph `index` (a cue, a suggestion), the caret after it.
    static func inserting(
        _ text: String, atOffset offset: Int, length: Int = 0, inParagraph index: Int, of paragraphs: [String]
    ) -> Edit {
        guard paragraphs.indices.contains(index) else { return Edit(paragraphs: paragraphs, caret: Caret(index: index, offset: offset)) }
        let current = paragraphs[index] as NSString
        let location = min(max(0, offset), current.length)
        let range = NSRange(location: location, length: min(max(0, length), current.length - location))
        var result = paragraphs
        result[index] = current.replacingCharacters(in: range, with: text)
        return Edit(paragraphs: result, caret: Caret(index: index, offset: location + (text as NSString).length))
    }

    /// A cue ("[pause]") at the caret: a space before it unless it starts the paragraph or follows
    /// a space, and one after it so the next word doesn't touch the bracket.
    static func cue(_ name: String, atOffset offset: Int, inParagraph index: Int, of paragraphs: [String]) -> Edit {
        guard paragraphs.indices.contains(index) else { return Edit(paragraphs: paragraphs, caret: Caret(index: index, offset: offset)) }
        let current = paragraphs[index] as NSString
        let location = min(max(0, offset), current.length)
        let before = current.substring(to: location)
        let needsSpace = !before.isEmpty && before.last?.isWhitespace == false
        return inserting((needsSpace ? " " : "") + "[\(name)] ", atOffset: location, inParagraph: index, of: paragraphs)
    }

    /// "New section at cursor": the paragraph splits at the caret.
    static func splitting(paragraphAt index: Int, atOffset offset: Int, in paragraphs: [String]) -> Edit {
        guard paragraphs.indices.contains(index) else { return Edit(paragraphs: paragraphs, caret: Caret(index: index, offset: 0)) }
        let current = paragraphs[index] as NSString
        let location = min(max(0, offset), current.length)
        let before = current.substring(to: location).trimmingCharacters(in: .whitespaces)
        let after = current.substring(from: location).trimmingCharacters(in: .whitespaces)
        var result = paragraphs
        result.replaceSubrange(index...index, with: [before, after])
        return Edit(paragraphs: result, caret: Caret(index: index + 1, offset: 0))
    }
}
