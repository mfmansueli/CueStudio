//
//  PendingTakeDeletions.swift
//  Cue Studio
//

import Foundation

/// Take videos Cue decided to delete, written down before each deletion runs: a deleted take whose Undo is still on screen, a deletion that
/// failed, a nameless video past its week (`TakeOrphanSweep`). If iOS ends Cue first, the next launch's sweep finishes it, unless the take came
/// back meanwhile.
struct PendingTakeDeletions {
    let defaults: UserDefaults

    var names: Set<String> { Set(defaults.stringArray(forKey: DefaultsKey.takeDeletionsPending) ?? []) }

    func add(_ added: some Sequence<String>) {
        write(names.union(added))
    }

    func remove(_ removed: some Sequence<String>) {
        write(names.subtracting(removed))
    }

    private func write(_ names: Set<String>) {
        if names.isEmpty {
            defaults.removeObject(forKey: DefaultsKey.takeDeletionsPending)
        } else {
            defaults.set(names.sorted(), forKey: DefaultsKey.takeDeletionsPending)
        }
    }
}
