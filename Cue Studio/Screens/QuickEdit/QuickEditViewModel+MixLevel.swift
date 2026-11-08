//
//  QuickEditViewModel+MixLevel.swift
//  Cue Studio
//

import Foundation

/// The preview plays the edit's sounds summed with no limiter (AVPlayer can't run one over the mix), the export mixes them through
/// one (`Mixdown`): when they go over full scale together, the preview distorts and the file doesn't, and comes out a little quieter.
/// Volume says so while it is open (owner, 06/11/2026: a short notice there, not a second preview engine).
extension QuickEditViewModel {
    /// How long the edit must stay the same before its mix is measured: a slider being dragged measures once, when it rests.
    static let mixMeasureDelay = Duration.milliseconds(700)

    /// Mixes the edit's sounds in the background and sets `mixTooLoud` (Volume runs it while open, again after every change; leaving
    /// it cancels the measurement). An edit with one sound is never measured.
    func measureMix() async {
        try? await Task.sleep(for: Self.mixMeasureDelay)
        guard !Task.isCancelled, source == .ready else { return }
        let measured = edit
        let peak = try? await editing.mixPeak(forVideoAt: videoURL, edit: measured)
        guard !Task.isCancelled, measured == edit else { return }
        mixTooLoud = (peak ?? 0) > 1
    }
}
