//
//  CaptionsViewModel+Emphasis.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Words the creator marks for emphasis (Caption › More › Emphasis, and Select's Emphasis for whole lines): they stay in the
/// style's emphasis color and size for as long as the line shows, unlike the word being said. A mark never cuts the lines again
/// (the line being worked on stays the same line): its line is drawn with the bigger word in its room, and the next cut (a
/// format, a size, a style) measures it. Each mark is one undo step.
///
/// Suggest emphasis (owner, 08/11/2026), off by default, puts at most one word a line where the line has a clear one
/// (`CaptionEmphasisSuggester`), never in a line with marks of the creator's. A suggestion shows on its chip and is taken away with a
/// tap, and then never comes back on its own; turning it off takes away only the suggestions. It is apart from the word being said.
extension CaptionsViewModel {
    /// How many marked words in a line still read as emphasis (Captions' own advice: one or two).
    static let emphasisPerLine = 2

    /// The line's words, which are marked, and which of those Suggest emphasis put.
    func captionEmphasisWords(_ cueID: UUID) -> [(word: String, isMarked: Bool, isSuggested: Bool)] {
        guard let line = edit.captions.first(where: { $0.id == cueID }) else { return [] }
        let marks = line.shownEmphasis
        return CaptionText.words(in: line.text).enumerated().map { ($1, marks.contains($0), line.suggestedEmphasis.contains($0)) }
    }

    /// Suggest emphasis is on for this video.
    var suggestsEmphasis: Bool { edit.suggestsEmphasis }

    /// Turns Suggest emphasis on (each line with a clear word gets it marked, one undo step, and the toast says how many) or off
    /// (the suggestions go, the creator's marks stay).
    func setSuggestsEmphasis(_ isOn: Bool) {
        guard isReady, canMarkCaptionEmphasis, isOn != edit.suggestsEmphasis else { return }
        let language = edit.captionLanguage.map { NLLanguage(rawValue: $0.languageCode) }
        let found = isOn ? CaptionEmphasisSuggester.suggestions(for: edit.captions, language: language) : [:]
        changeEdit { edit in
            edit.suggestsEmphasis = isOn
            edit.captions = edit.captions.map { line in
                var line = line
                if isOn, let index = found[line.id] {
                    line.emphasis.insert(index)
                    line.suggestedEmphasis.insert(index)
                } else if !isOn {
                    line.emphasis.subtract(line.suggestedEmphasis)
                    line.suggestedEmphasis = []
                }
                return line
            }
        }
        if isOn {
            sayUndoable(
                found.isEmpty
                    ? String(localized: "No line has a clear word to emphasize")
                    : String(localized: "Emphasis suggested in \(found.count) lines · open a line to review")
            )
        } else {
            sayUndoable(String(localized: "Suggested emphasis off · your marks stay"))
        }
    }

    /// Emphasis can be marked: the captions are drawn by the collection.
    var canMarkCaptionEmphasis: Bool { edit.captionCollection != nil }

    /// Marks or unmarks the line's word at `index`, then shows the line: the playhead goes to it unless it is already on it
    /// (Choose words to emphasize opens the line under the playhead, and the way back puts the playhead where it was).
    func toggleCaptionEmphasis(_ cueID: UUID, word index: Int) {
        guard isReady, canMarkCaptionEmphasis else { return }
        change { snapshot in
            guard var lines = snapshot.captions, let at = lines.firstIndex(where: { $0.id == cueID }) else { return }
            if lines[at].suggestedEmphasis.contains(index) {
                // A suggestion taken away stays away.
                lines[at].suggestedEmphasis.remove(index)
                lines[at].emphasis.remove(index)
                lines[at].declinedEmphasis.insert(index)
            } else if lines[at].emphasis.contains(index) {
                lines[at].emphasis.remove(index)
            } else {
                lines[at].emphasis.insert(index)
                lines[at].declinedEmphasis.remove(index)
            }
            snapshot.captions = lines
            Self.convertCopiedLook(&snapshot)
        }
        if let span = editedSpan(ofCaption: cueID), !(span.start <= player.currentTime && player.currentTime < span.end) {
            player.pause()
            player.seek(to: span.start + 0.05)
        }
    }

    /// The line has more marked words than read as emphasis.
    func hasTooMuchEmphasis(_ cueID: UUID) -> Bool {
        (edit.captions.first { $0.id == cueID }?.shownEmphasis.count ?? 0) > Self.emphasisPerLine
    }

    /// Captions drawn with a look an earlier version copied from a text are drawn by the collection once words are marked.
    static func convertCopiedLook(_ snapshot: inout EditSnapshot) {
        guard let settings = snapshot.captionCollection, settings.customLook != nil else { return }
        snapshot.captionCollection = settings.withoutCopiedLook
    }

}
