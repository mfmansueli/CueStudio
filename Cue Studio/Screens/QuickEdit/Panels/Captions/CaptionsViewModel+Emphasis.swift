//
//  CaptionsViewModel+Emphasis.swift
//  Cue Studio
//

import Foundation

/// Words the creator marks for emphasis (Caption › More › Emphasis, and Select's Emphasis for whole lines): they stay in the
/// style's emphasis color and size for as long as the line shows, unlike the word being said. A mark never cuts the lines again
/// (the line being worked on stays the same line): its line is drawn with the bigger word in its room, and the next cut (a
/// format, a size, a style) measures it. Each mark is one undo step.
extension CaptionsViewModel {
    /// How many marked words in a line still read as emphasis (Captions' own advice: one or two).
    static let emphasisPerLine = 2

    /// The line's words, and which are marked.
    func captionEmphasisWords(_ cueID: UUID) -> [(word: String, isMarked: Bool)] {
        guard let line = edit.captions.first(where: { $0.id == cueID }) else { return [] }
        let marks = line.shownEmphasis
        return CaptionText.words(in: line.text).enumerated().map { ($1, marks.contains($0)) }
    }

    /// Emphasis can be marked: the captions are drawn by the collection.
    var canMarkCaptionEmphasis: Bool { edit.captionCollection != nil }

    /// Marks or unmarks the line's word at `index`, then shows the line.
    func toggleCaptionEmphasis(_ cueID: UUID, word index: Int) {
        guard isReady, canMarkCaptionEmphasis else { return }
        change { snapshot in
            guard var lines = snapshot.captions, let at = lines.firstIndex(where: { $0.id == cueID }) else { return }
            if lines[at].emphasis.contains(index) { lines[at].emphasis.remove(index) } else { lines[at].emphasis.insert(index) }
            snapshot.captions = lines
            Self.convertCopiedLook(&snapshot)
        }
        if let span = editedSpan(ofCaption: cueID) {
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
