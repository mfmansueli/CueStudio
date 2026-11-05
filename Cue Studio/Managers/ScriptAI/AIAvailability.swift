//
//  AIAvailability.swift
//  Cue Studio
//

import Foundation

/// Which Apple Intelligence models can run right now, and why not when neither can. The
/// teleprompter never depends on this; only AI features are turned off.
nonisolated struct AIAvailability: Hashable, Sendable {
    var onDevice: Bool
    var privateCloud: Bool
    /// Why AI is off, in words for the creator. Nil while any model is available.
    var reason: String?

    var isAvailable: Bool { onDevice || privateCloud }

    /// The creator switched Apple Intelligence off in Settings › Privacy & AI data.
    /// Read each time, so it is always in the interface's language of the moment.
    static var turnedOffReason: String { String(localized: "Turned off in Settings › Privacy & AI data.") }

    /// Made each time, so its reason is in the interface's language of the moment (made once, it stayed in the language of the first read).
    static var unavailable: AIAvailability {
        AIAvailability(onDevice: false, privateCloud: false, reason: String(localized: "Requires Apple Intelligence."))
    }
}
