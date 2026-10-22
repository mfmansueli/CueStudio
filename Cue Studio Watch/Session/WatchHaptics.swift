//
//  WatchHaptics.swift
//  Cue Studio Watch
//

import WatchKit

/// The wrist's taps, only after the iPhone confirms (v31 board): one each, never every second of the countdown nor while
/// the creator speaks.
enum WatchHaptics {
    static func screenChanged(from old: WatchScreen, to new: WatchScreen) {
        guard let haptic = haptic(from: old, to: new) else { return }
        WKInterfaceDevice.current().play(haptic)
    }

    static func haptic(from old: WatchScreen, to new: WatchScreen) -> WKHapticType? {
        switch (old, new) {
        case (.countdown, .countdown): nil
        case (_, .countdown): .click
        case (.recording, .recording), (.stopping, .recording): nil
        case (_, .recording): .start
        case (.recording, .saving), (.stopping, .saving): .stop
        case (.saved, .saved): nil
        case (_, .saved): .success
        case (.lost, .lost), (.noResponse, .noResponse), (.failedStart, .failedStart), (.failedSave, .failedSave): nil
        case (_, .lost), (_, .noResponse), (_, .failedStart), (_, .failedSave): .failure
        default: nil
        }
    }
}
