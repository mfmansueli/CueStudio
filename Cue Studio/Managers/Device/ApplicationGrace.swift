//
//  ApplicationGrace.swift
//  Cue Studio
//

import UIKit

/// The few seconds iOS gives an app that leaves (`beginBackgroundTask`), ended by whoever comes first: the work, or iOS when
/// the time is up. Ended once, however many times it is asked to.
@MainActor
final class ApplicationGrace {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    /// Asks iOS for the time; the closure returned gives it back.
    static func begin(named name: String) -> @MainActor () -> Void {
        let grace = ApplicationGrace()
        grace.identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [grace] in
            Task { @MainActor in grace.end() }
        }
        return { grace.end() }
    }

    private func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
