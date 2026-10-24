//
//  LinesChange.swift
//  Cue Studio
//

import Foundation

/// An undo step's lines (caption lines, a translation's lines) as a saved draft keeps them (`EditSnapshot.thinned`): written
/// as a change of the lines of the state the step is applied on, so a take of hundreds of lines proofread line by line writes
/// each corrected line once, not every line in every step. `lines` are the step's lines that aren't there as they are in the
/// step; `order` is the order of all of the step's lines by identity, only when lines came, went or moved (nil: the same
/// lines in the same order).
nonisolated struct LinesChange<Line: Codable & Hashable & Identifiable & Sendable>: Codable, Hashable, Sendable where Line.ID == UUID {
    var lines: [Line]
    var order: [UUID]?

    /// The change that makes `newer` into `step`.
    init(from newer: [Line], to step: [Line]) {
        let known = Dictionary(newer.map { ($0.id, $0) }) { first, _ in first }
        lines = step.filter { known[$0.id] != $0 }
        order = step.map(\.id) == newer.map(\.id) ? nil : step.map(\.id)
    }

    /// The step's lines, from the lines of the state it is applied on; nil when they don't hold a line the order names (a
    /// draft out of step with its edit), so the lines are left as they are.
    func applied(to newer: [Line]) -> [Line]? {
        var byID = Dictionary(newer.map { ($0.id, $0) }) { first, _ in first }
        for line in lines { byID[line.id] = line }
        guard let order else {
            return newer.map { byID[$0.id] ?? $0 }
        }
        let result = order.compactMap { byID[$0] }
        return result.count == order.count ? result : nil
    }
}

nonisolated extension EditSnapshot {
    /// The caption lines of `step` as a change of `newer`'s, when fewer than half of them change (an order is only each line's
    /// identity); nil: write the lines themselves.
    static func captionChange(_ step: [CaptionCue], onto newer: [CaptionCue]) -> LinesChange<CaptionCue>? {
        let change = LinesChange(from: newer, to: step)
        return change.lines.count * 2 < step.count ? change : nil
    }

    /// The translations of `step` as a change of each language's lines in `newer`, when the same languages are there in the
    /// same order and fewer than half of their lines change; nil: write the translations themselves.
    static func translationChange(
        _ step: [CaptionTranslation], onto newer: [CaptionTranslation]
    ) -> [CueLanguage: LinesChange<TranslatedCaptionLine>]? {
        guard step.map(\.language) == newer.map(\.language) else { return nil }
        var changes: [CueLanguage: LinesChange<TranslatedCaptionLine>] = [:]
        var changed = 0
        for (mine, theirs) in zip(step, newer) where mine.lines != theirs.lines {
            let change = LinesChange(from: theirs.lines, to: mine.lines)
            changes[mine.language] = change
            changed += change.lines.count
        }
        return changed * 2 < step.reduce(0) { $0 + $1.lines.count } ? changes : nil
    }

    /// `translations` with each language's change applied; nil when one can't be, so they are left as they are.
    static func applying(_ changes: [CueLanguage: LinesChange<TranslatedCaptionLine>], to translations: [CaptionTranslation]) -> [CaptionTranslation]? {
        var result = translations
        for index in result.indices {
            guard let change = changes[result[index].language] else { continue }
            guard let lines = change.applied(to: result[index].lines) else { return nil }
            result[index].lines = lines
        }
        return result
    }
}
