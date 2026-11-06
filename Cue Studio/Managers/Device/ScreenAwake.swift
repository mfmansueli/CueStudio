//
//  ScreenAwake.swift
//  Cue Studio
//

import UIKit

/// Keeps the iPhone from locking by itself (`UIApplication.isIdleTimerDisabled`) while anything in Cue needs the screen on: the
/// prompter reading a script, the remote on a stand, an export that has to run with Cue open. One flag, many owners: each one
/// holds it by its own name, and the screen may lock again only when the last one lets go, so the prompter closing never
/// re-enables auto-lock under an export that still runs (or the other way round).
@MainActor
final class ScreenAwake {
    static let shared = ScreenAwake()

    private var owners: Set<String> = []
    /// Sets the system's flag; a test records it instead.
    private let apply: @MainActor (Bool) -> Void

    init(apply: @escaping @MainActor (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }) {
        self.apply = apply
    }

    /// Whether someone holds the screen on.
    var isHeld: Bool { !owners.isEmpty }

    /// `owner` needs the screen on. Holding twice under one name is holding once.
    func hold(_ owner: String) {
        let wasHeld = isHeld
        owners.insert(owner)
        if !wasHeld { apply(true) }
    }

    /// `owner` no longer needs it; auto-lock comes back once nobody does. Letting go of what isn't held changes nothing.
    func release(_ owner: String) {
        guard owners.remove(owner) != nil, owners.isEmpty else { return }
        apply(false)
    }
}
