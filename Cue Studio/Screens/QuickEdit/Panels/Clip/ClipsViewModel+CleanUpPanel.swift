//
//  ClipsViewModel+CleanUpPanel.swift
//  Cue Studio
//

import Foundation

/// Clean up (pt "Limpar fala", D6): one panel with three tabs. **Pauses**: the silences, how much of each stays ("Gap left"),
/// the silence before the first word, and what was removed, to put back one by one. **Words**: hesitations and repeats, and
/// the tries at a script line said more than once. **Text**: Edit by text, with the hesitations underlined and the pauses
/// marked in the words. The marks are the same on every tab and Remove takes out what is marked on all of them; ✓ closes
/// without removing anything. The panel grows in place for Text (the video at its smallest, still playing), and the creator
/// can make it taller or shorter on any tab; it never opens as another sheet. Pauses need no words: they come from the
/// loudness, in every language.
extension ClipsViewModel {
    /// Opens Clean up on `tab`: Pauses from its tool, Text from Edit by text.
    func openCleanUp(on tab: EditorPanelTab = .pauses) {
        guard EditorPanelTab.cleanUp.contains(tab) else { return }
        if panel == .pauses {
            showCleanUpTab(tab)
            return
        }
        cleanUpOpensOn = tab
        panel = .pauses
    }

    /// The tab on show, Pauses when the panel isn't Clean up's.
    var cleanUpTab: EditorPanelTab {
        EditorPanelTab.cleanUp.contains(panelTab) ? panelTab : .pauses
    }

    /// Another tab: the marks and a pick in the words stay; Text makes the panel tall for reading, and no tab makes it shorter.
    func showCleanUpTab(_ tab: EditorPanelTab) {
        guard EditorPanelTab.cleanUp.contains(tab), tab != cleanUpTab else { return }
        Haptics.selection()
        panelTab = tab
        if tab == .transcript { cleanUpIsExpanded = true }
    }

    // MARK: - What the tabs say

    /// The take was heard as too noisy to tell its pauses from its speech (`CleanUpHearing.isInconclusive`).
    var cleanUpIsInconclusive: Bool { edit.cleanUpHearing?.isInconclusive ?? false }

    /// "No pauses longer than 0.7s".
    var noPausesTitle: String {
        String(localized: "No pauses longer than \(DurationText.tenths(pauseThreshold))")
    }

    /// The shorter length "Try" offers when nothing was found (0.2 s shorter), nil at the shortest.
    var shorterPauseThreshold: TimeInterval? {
        let lowest = Self.pauseThresholdRange.lowerBound
        guard pauseThreshold > lowest + 0.001 else { return nil }
        return max(lowest, ((pauseThreshold - 0.2) * 10).rounded() / 10)
    }

    /// "Try 0.5s": lists the shorter pauses.
    func tryShorterPauses() {
        guard let shorter = shorterPauseThreshold else { return }
        Haptics.selection()
        pauseThreshold = shorter
    }

    /// Why Words may be missing something, or nil when it has the whole story: the words couldn't be heard (no speech model for
    /// the language on this iPhone, or listening failed), or they were heard in a language without known hesitations.
    var wordsNote: String? {
        guard let hearing = edit.cleanUpHearing else { return nil }
        guard let language = hearing.wordsLanguage else {
            return String(localized: "Cue couldn't hear the words of this take on this iPhone. Pauses still work.")
        }
        guard FillerWordDetector.sounds[language] == nil else { return nil }
        return String(localized: "Ums: English, Portuguese and Spanish. Pauses work in every language.")
    }

    /// What finding the tries at a script line needs, when this take doesn't have it.
    var scriptRetakesNote: String? {
        guard captionScript?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true else { return nil }
        return String(localized: "This take has no script, so only words said twice in a row are found as repeats.")
    }
}
