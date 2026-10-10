//
//  VoyageNotice.swift
//  Cue Studio
//

import Foundation

/// The short notice when a step of the first voyage gets done: "✓ Rehearsed · Next: record". Said only when its "Next" is true (the step
/// after it is the one now ahead), so a creator who did two steps at once never hears about one that is already behind them; the
/// first video shared always says it. Write, Pick and a Polish without captions pass quietly: their tips already said the next thing.
/// Pure, so every case is tested without the app.
nonisolated enum VoyageNotice {
    /// What to say for the steps just done (`newlyDone`) with `progress` as it is now; nil to say nothing.
    static func message(newlyDone: Set<VoyageStep>, progress: VoyageProgress, hasCaptions: Bool) -> String? {
        if newlyDone.contains(.share) { return String(localized: "✓ Your first star is out there") }
        guard let step = newlyDone.max(by: { $0.rawValue < $1.rawValue }), progress.current == step.following else { return nil }
        switch step {
        case .practice: return String(localized: "✓ Rehearsed · Next: record")
        case .record: return String(localized: "✓ Recorded · Next: pick a take")
        case .polish: return hasCaptions ? String(localized: "✓ Captions on · Next: share") : nil
        case .write, .pick, .share: return nil
        }
    }
}
