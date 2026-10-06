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
    static let turnedOffReason = String(localized: "Turned off in Settings › Privacy & AI data.")

    static let unavailable = AIAvailability(
        onDevice: false, privateCloud: false,
        reason: String(localized: "Requires Apple Intelligence.")
    )
}
