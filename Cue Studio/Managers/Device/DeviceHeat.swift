//
//  DeviceHeat.swift
//  Cue Studio
//

import Foundation

/// What a hot iPhone means for an export: the system slows the chip down, so the export takes longer. Cue says so (never
/// lowering the quality, never touching the animations) and the creator decides whether to wait for it to cool down.
nonisolated enum DeviceHeat {
    /// The line under the export, or nil when the iPhone is cool enough not to matter.
    static func exportNote(for state: ProcessInfo.ThermalState) -> String? {
        switch state {
        case .serious, .critical:
            String(localized: "The iPhone is hot, so the export takes longer. Let it cool down if you can.")
        default:
            nil
        }
    }
}
