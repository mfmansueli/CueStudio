import Foundation

/// Whether platform duration guides composition or is only a reference for the creator.
/// The app keeps its existing default while the informative variant is evaluated on-device.
nonisolated enum ScriptDurationPolicy: String, Sendable, Hashable {
    case targeted
    case informative
}
