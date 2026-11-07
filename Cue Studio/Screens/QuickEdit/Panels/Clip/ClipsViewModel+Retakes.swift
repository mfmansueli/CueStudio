//
//  ClipsViewModel+Retakes.swift
//  Cue Studio
//

import Foundation

/// Clean up › Words › the lines of the script said more than once (plan §10): each try is identified ("Try 2 of 3"), can be
/// heard on its own, and the creator keeps one, which marks the others to go. Nothing is marked until then (a try is never
/// sure), and the last try isn't assumed to be the best. A take without a script still gets the repeats said twice in a row.
extension ClipsViewModel {
    /// The tries still playing, by line, in the order the edit plays them.
    var retakeGroups: [CleanUpRetakeGroup] {
        let tries = wordCandidates.filter { $0.attempt != nil }
        var order: [UUID] = []
        var byGroup: [UUID: [CleanUpSuggestion]] = [:]
        for attempt in tries {
            guard let group = attempt.attempt?.group else { continue }
            if byGroup[group] == nil { order.append(group) }
            byGroup[group, default: []].append(attempt)
        }
        return order.compactMap { id in
            guard let tries = byGroup[id], let line = tries.first?.attempt?.line, tries.count >= 2 else { return nil }
            return CleanUpRetakeGroup(id: id, line: line, tries: tries.sorted { ($0.attempt?.number ?? 0) < ($1.attempt?.number ?? 0) })
        }
    }

    /// The fillers and repeats that aren't tries at a script line (and the tries of a line with only one left playing).
    var hesitationCandidates: [CleanUpSuggestion] {
        let grouped = Set(retakeGroups.flatMap(\.tries).map(\.id))
        return wordCandidates.filter { !grouped.contains($0.id) }
    }

    /// Whether the creator kept this try: it is the one not marked while the others of its line are.
    func isKeptTry(_ attempt: CleanUpSuggestion, in group: CleanUpRetakeGroup) -> Bool {
        !isMarked(attempt) && group.tries.contains { $0.id != attempt.id && isMarked($0) }
    }

    /// "Keep this one": this try stays, the line's other tries are marked to go. Tapped again, nothing of the line is marked.
    func keepTry(_ id: UUID, in group: CleanUpRetakeGroup) {
        guard let picked = group.tries.first(where: { $0.id == id }) else { return }
        Haptics.selection()
        let undo = isKeptTry(picked, in: group)
        for attempt in group.tries {
            cleanUpMarks[attempt.id] = undo ? false : attempt.id != id
        }
    }

    /// "Try 2 of 3".
    func tryLabel(_ attempt: CleanUpSuggestion) -> String {
        guard let number = attempt.attempt?.number, let count = attempt.attempt?.count else { return attempt.title }
        return String(localized: "Try \(number) of \(count)", comment: "Clean up › Words: one of the times a script line was said")
    }

    /// Listen to a try: it plays on its own, from a moment before it to a moment after.
    func listenToTry(_ id: UUID) {
        guard isReady, let attempt = edit.suggestions.first(where: { $0.id == id }), let span = edit.timeline.editedSpan(of: attempt) else { return }
        listeningID = id
        let part = max(0, span.start - 0.2)...min(edit.editedDuration, span.end + 0.2)
        play([part], back: max(0, span.start - 0.3))
    }
}
