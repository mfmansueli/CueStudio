//
//  QuickEditViewModel+LowPower.swift
//  Cue Studio
//

import Foundation

/// The Low Power Mode notice over the preview: the screen runs at 60 frames per second and editing and exports are slower,
/// so it suggests turning the mode off in Control Center (no app can turn it off or open Battery settings). It shows while
/// the mode is on, at most once a day (`LowPowerNotice`), and goes as soon as the mode is turned off or its ✕ is tapped.
extension QuickEditViewModel {
    /// Low Power Mode is `isOn` now: when the editor opens and every time it changes.
    func lowPowerModeChanged(_ isOn: Bool, now: Date = .now) {
        guard isOn else {
            showsLowPowerNotice = false
            return
        }
        guard !showsLowPowerNotice,
              LowPowerNotice.shows(isLowPower: true, lastShown: editorPreferences.lowPowerNoticeShownAt, now: now) else { return }
        showsLowPowerNotice = true
        editorPreferences.lowPowerNoticeShownAt = now
    }

    func dismissLowPowerNotice() {
        showsLowPowerNotice = false
    }
}
