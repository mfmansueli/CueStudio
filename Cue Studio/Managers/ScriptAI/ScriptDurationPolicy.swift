import Foundation

/// Whether platform duration guides composition or is only a reference for the creator.
/// Automatic requests use an informative reference; explicit creator choices retain a target.
nonisolated enum ScriptDurationPolicy: String, Sendable, Hashable {
    case targeted
    case informative
}
