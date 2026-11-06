//
//  LogbookComposerInput.swift
//  Cue Studio
//

import Foundation

/// What a change in the Logbook's field means. The field grows with a long idea, so Return arrives as a line break: one line break at
/// the end (or the only character added, where the caret was) is Return, and saves the idea. A pasted text that brings its own line
/// breaks keeps its lines, joined by spaces (an idea is one paragraph), and waits to be saved like any typed one.
nonisolated enum LogbookComposerInput {
    enum Outcome: Equatable {
        /// Words being typed: nothing to do.
        case keep
        /// Pasted lines: the field shows them as one paragraph.
        case replace(String)
        /// Return: these words are saved.
        case save(String)
    }

    static func change(from old: String, to new: String) -> Outcome {
        guard new.contains(where: \.isNewline) else { return .keep }
        // Return: one line break, at the end, or the only character added. It can come with other changes in the same update
        // (fast typing, autocorrect fixing the last word as Return is pressed), so the length alone can't tell.
        let breaks = new.filter(\.isNewline).count
        if breaks == 1, new.last?.isNewline == true || new.count == old.count + 1 {
            return .save(new.filter { !$0.isNewline })
        }
        let lines = new.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return .replace(lines.joined(separator: " "))
    }
}
