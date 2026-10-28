//
//  VolumeRamp.swift
//  Cue Studio
//

import AVFoundation

/// A change of a track's volume on the composition's clock: a ramp over `range`, or `to` from its start when it takes no time.
nonisolated struct VolumeRamp: Equatable, Sendable {
    static let timescale: CMTimeScale = 600

    let range: CMTimeRange
    let from: Float
    let to: Float

    /// `fades`, in order, on whole ticks of the clock, each from where the one before ended. AVFoundation stops the app on a ramp
    /// that starts inside another (a clip's sound Fade out as long as the slider goes once started 5 ms into the short ramp to the
    /// clip's volume: two crashes on the iPhone, 28/10/2026). `EditedComposition.levels` keeps them apart; this makes sure on the
    /// clock, where times are cut to ticks: each ramp ends on its own end time, never on its length, and never starts before the
    /// last one ended.
    static func scheduled(_ fades: [EditedComposition.Fade]) -> [VolumeRamp] {
        var ramps: [VolumeRamp] = []
        var reached = CMTime.zero
        for fade in fades {
            let start = max(time(fade.start), reached)
            let end = max(start, time(fade.start + max(0, fade.duration)))
            ramps.append(VolumeRamp(range: CMTimeRange(start: start, end: end), from: fade.fromVolume, to: fade.toVolume))
            reached = end
        }
        return ramps
    }

    /// Puts `ramps` on `parameters`: a ramp, or the level from its start when it takes no time.
    static func apply(_ ramps: [VolumeRamp], to parameters: AVMutableAudioMixInputParameters) {
        for ramp in ramps {
            if ramp.range.duration > .zero {
                parameters.setVolumeRamp(fromStartVolume: ramp.from, toEndVolume: ramp.to, timeRange: ramp.range)
            } else {
                parameters.setVolume(ramp.to, at: ramp.range.start)
            }
        }
    }

    private static func time(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: max(0, seconds), preferredTimescale: timescale)
    }
}
