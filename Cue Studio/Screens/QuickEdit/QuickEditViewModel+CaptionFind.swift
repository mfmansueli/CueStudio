//
//  QuickEditViewModel+CaptionFind.swift
//  Cue Studio
//

import Foundation

/// Find and replace in the captions (`CaptionFindSheet`, as in CapCut's caption editor): a word is looked for in every line
/// that plays, in play order; each match can be replaced on its own, or all of them at once. Every replace is one undo step
/// and changes only the words: the lines keep their times (`CaptionFindReplace`).
extension QuickEditViewModel {
    /// Opens Find and replace over the editor (the video stops, the lines stay where they are).
    func openCaptionFind() {
        guard isReady, !edit.captions.isEmpty else { return }
        player.pause()
        toolMenu = nil
        sheet = .findInCaptions
    }

    /// The lines that play, each once, in the order they play (a copied clip shows a line again: it is still one line).
    var captionLinesInPlayOrder: [CaptionCue] {
        var seen: Set<UUID> = []
        let lines = Dictionary(edit.captions.map { ($0.id, $0) }) { first, _ in first }
        return captionListLines.compactMap { instance in
            guard seen.insert(instance.cueID).inserted else { return nil }
            return lines[instance.cueID]
        }
    }

    /// Every match of `query` in the lines that play.
    func captionMatches(for query: String) -> [CaptionFindReplace.Match] {
        CaptionFindReplace.matches(of: query, in: captionLinesInPlayOrder)
    }

    /// "Replace" on one match: that match only, one undo step.
    func replaceCaptionMatch(_ match: CaptionFindReplace.Match, query: String, with replacement: String) {
        guard isReady else { return }
        let changed = replaceInCaptions { cueID, text in
            guard cueID == match.cueID else { return nil }
            return CaptionFindReplace.replacing(query, with: replacement, in: text, occurrence: match.occurrence)
        }
        guard changed > 0 else { return }
        Haptics.selection()
        toast.show(String(localized: "Replaced"))
    }

    /// "Replace all": every match in every line that plays, one undo step (Undo in the toast brings them all back).
    @discardableResult
    func replaceAllCaptionMatches(_ query: String, with replacement: String) -> Int {
        guard isReady else { return 0 }
        let count = captionMatches(for: query).count
        guard count > 0 else { return 0 }
        let playing = Set(captionLinesInPlayOrder.map(\.id))
        replaceInCaptions { cueID, text in
            playing.contains(cueID) ? CaptionFindReplace.replacing(query, with: replacement, in: text) : nil
        }
        Haptics.selection()
        toast.show(
            String(localized: "Replaced \(count) times"),
            action: undoAction
        )
        return count
    }

    /// Sets the new text of every line `replace` returns one for (nil leaves the line), in one undo step. Returns how many
    /// lines changed. A line the replacement empties stays, empty, so its time can be written again or deleted.
    @discardableResult
    private func replaceInCaptions(_ replace: (UUID, String) -> String?) -> Int {
        var changed = 0
        change { snapshot in
            guard var lines = snapshot.captions else { return }
            for index in lines.indices {
                guard let text = replace(lines[index].id, lines[index].text), text != lines[index].text else { continue }
                lines[index] = CaptionRevision.retimed(lines[index], text: text)
                changed += 1
            }
            snapshot.captions = lines
        }
        return changed
    }
}
