//
//  LibraryHistory.swift
//  Cue Studio
//

import Foundation

/// Whether this creator has ever had a script (written, imported or seeded): it tells the first-use empty state from the returning one
/// (`ScriptsEmptyState`). Kept in UserDefaults and only ever turned on: deleting every script doesn't make a creator new again. A creator
/// who already has scripts when the app opens counts as returning from that moment.
@MainActor
@Observable
final class LibraryHistory {
    private(set) var hasEverHadScript: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        hasEverHadScript = defaults.bool(forKey: DefaultsKey.hasEverHadScript)
    }

    /// The library holds `scriptCount` scripts now (called when it loads and whenever it changes).
    func note(scriptCount: Int) {
        guard scriptCount > 0, !hasEverHadScript else { return }
        hasEverHadScript = true
        defaults.set(true, forKey: DefaultsKey.hasEverHadScript)
    }

    func state(hasLoaded: Bool, scriptCount: Int) -> ScriptsEmptyState {
        ScriptsEmptyState.resolve(hasLoaded: hasLoaded, scriptCount: scriptCount, hasEverHadScript: hasEverHadScript)
    }
}
