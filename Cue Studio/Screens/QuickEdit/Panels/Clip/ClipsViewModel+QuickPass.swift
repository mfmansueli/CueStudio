//
//  ClipsViewModel+QuickPass.swift
//  Cue Studio
//

import Foundation

/// Quick pass (E4 decision A, owner 07/11/2026: in Clean up, because it only touches the speech): one tap marks everything
/// Clean up is clear about, so Remove takes it all out in one undo step after a look. Clear pauses and hesitations are marked
/// already (`isMarked`); what Quick pass adds is a choice for each line said more than once that has none: the last try stays
/// (a creator's last try is usually the one that went through), its earlier tries are marked. Nothing is cut until Remove; each
/// mark can still be changed. A mark the creator took off stays off.
extension ClipsViewModel {
    /// The lines said more than once with no try kept yet.
    var undecidedRetakeGroups: [CleanUpRetakeGroup] {
        retakeGroups.filter { group in !group.tries.contains { $0.attempt?.kept == true } }
    }

    /// Whether Quick pass has something to mark: a line said more than once with no choice, or anything left to remove.
    var canQuickPass: Bool {
        analysis == .done && (!undecidedRetakeGroups.isEmpty || !markedCleanUp.isEmpty)
    }

    /// Keeps the last try of every undecided line (one undo step) and says what Remove would now take out.
    func quickPass() {
        guard isReady, analysis == .done else { return }
        let groups = keepLastTries()
        Haptics.selection()
        let count = markedCleanUp.count
        guard count > 0 else {
            toast.show(String(localized: "Nothing clear to take out"))
            return
        }
        let seconds = DurationText.tenths(cleanUpSaving)
        toast.show(
            groups > 0
                ? String(localized: "Marked \(count) · the last try of each repeated line stays · Remove takes out \(seconds)")
                : String(localized: "Marked \(count) · Remove takes out \(seconds)")
        )
    }

    /// The last try of every undecided line kept, in one change; how many lines.
    @discardableResult
    func keepLastTries() -> Int {
        let picks = undecidedRetakeGroups.compactMap { group in group.tries.last.map { (group, $0.id) } }
        guard !picks.isEmpty else { return 0 }
        let kept = Set(picks.map(\.1))
        let tries = Set(picks.flatMap { $0.0.tries.map(\.id) })
        // A try the creator unmarked stays unmarked; any other mark follows the kept try.
        for id in tries where cleanUpMarks[id] == true { cleanUpMarks[id] = nil }
        changeEdit { edit in
            for index in edit.suggestions.indices where tries.contains(edit.suggestions[index].id) {
                let isKept = kept.contains(edit.suggestions[index].id)
                edit.suggestions[index].attempt?.kept = isKept ? true : nil
            }
        }
        return picks.count
    }
}
