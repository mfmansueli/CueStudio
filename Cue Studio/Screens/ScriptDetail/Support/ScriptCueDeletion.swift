//
//  ScriptCueDeletion.swift
//  Cue Studio
//

import Foundation

/// A cue is one thing on the page: deleting into it deletes all of it. Backspace after "[pause]" takes the whole tag in one press
/// instead of leaving "[paus" behind, and so does any deletion that cuts into a cue (forward delete, a selection that starts or ends
/// inside one). Offsets are characters from the start of the text, as the page's selection counts them.
nonisolated enum ScriptCueDeletion {
    struct Result: Equatable {
        let text: String
        /// Where the caret goes: where the cue was.
        let caret: Int
    }

    /// `old` became `new` by removing characters. When what was removed cut into a cue, the whole cue goes too, and so does the
    /// space it leaves doubled; nil when the change wasn't a plain deletion or didn't touch a cue.
    static func completing(from old: String, to new: String) -> Result? {
        let before = Array(old)
        let after = Array(new)
        guard after.count < before.count else { return nil }
        var prefix = 0
        while prefix < after.count, before[prefix] == after[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < after.count - prefix, before[before.count - 1 - suffix] == after[after.count - 1 - suffix] { suffix += 1 }
        // Something was typed as well (a selection replaced): not a deletion.
        guard prefix + suffix == after.count else { return nil }

        var lower = prefix
        var upper = before.count - suffix
        var cutIntoCue = false
        for cue in cues(in: before) where cue.overlaps(lower..<upper) && !(lower <= cue.lowerBound && cue.upperBound <= upper) {
            lower = min(lower, cue.lowerBound)
            upper = max(upper, cue.upperBound)
            cutIntoCue = true
        }
        guard cutIntoCue else { return nil }
        // "talk [pause] more" leaves "talk more", not "talk  more"; a cue that opened the text takes the space after it.
        if upper < before.count, before[upper] == " ", lower == 0 || before[lower - 1] == " " {
            upper += 1
        }
        return Result(text: String(before[..<lower] + before[upper...]), caret: lower)
    }

    /// Where the cues are, as the page draws them: "[" then at least one character up to "]", on one line.
    static func cues(in characters: [Character]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var index = 0
        while index < characters.count {
            guard characters[index] == "[" else {
                index += 1
                continue
            }
            var end = index + 1
            while end < characters.count, characters[end] != "]", characters[end] != "\n" { end += 1 }
            if end < characters.count, characters[end] == "]", end > index + 1 {
                ranges.append(index..<(end + 1))
                index = end + 1
            } else {
                index += 1
            }
        }
        return ranges
    }
}
