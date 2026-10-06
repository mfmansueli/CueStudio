//
//  PrompterViewModel+Review.swift
//  Cue Studio
//

import Foundation

extension PrompterViewModel {
    func openLastTake() {
        guard let lastTake, !isRecording else { return }
        pause()
        reviewingTake = lastTake
    }

    /// 04 · F3: a stop that leaves two takes or more of the script and no ★ opens "Pick your best take" first; a single
    /// take (or a freestyle one, which has no siblings) goes straight to its review.
    func shouldPickBest(after take: Take) -> Bool {
        guard let scriptID = take.scriptID else { return false }
        let siblings = takes.takes(for: scriptID)
        return siblings.count > 1 && !siblings.contains(where: \.isBest)
    }
}
