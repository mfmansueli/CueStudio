//
//  EyeContactState.swift
//  Cue Studio
//

import Foundation

/// Where Eye Contact stands for the edit, as the panel and the ✦ Smart tile say it. "On" is only the setting: the line under it
/// says how much of the video is corrected once that's known, and never claims "done" while only the stretch on screen is. Pure.
nonisolated enum EyeContactState: Equatable {
    case off
    /// The model or the GPU can't run on this iPhone.
    case unavailable
    /// Finding the eyes, with how much is done (0 to 1); `readyHere` once the stretch on screen is ready.
    case preparing(Double, readyHere: Bool)
    /// Waiting (the iPhone is hot, or Cue is in the background), with how much is done.
    case paused(MotionAnalysisPause, Double)
    /// Everything analyzed: the share of the video's frames corrected (fully or partly).
    case ready(Double)
    /// Everything analyzed and nothing to correct, with the main reason.
    case nothingToCorrect(EyeContactHold?)
    /// A recording couldn't be read.
    case failed

    /// The line under the panel's controls.
    var note: String? {
        switch self {
        case .off:
            return nil
        case .unavailable:
            return String(localized: "Eye Contact isn’t available on this iPhone")
        case .preparing(let done, let readyHere):
            let percent = Self.percent(done)
            return readyHere
                ? String(localized: "Ready here · finding your eyes in the rest · \(percent)%")
                : String(localized: "Finding your eyes · \(percent)%")
        case .paused(.heat, let done):
            return String(localized: "Waiting for the iPhone to cool down · \(Self.percent(done))%")
        case .paused(.background, let done):
            return String(localized: "Goes on when Cue is open · \(Self.percent(done))%")
        case .ready(let share):
            return String(localized: "Corrects \(Self.percent(share))% of the video. Blinks and looks away stay as filmed.")
        case .nothingToCorrect(let hold):
            switch hold {
            case .otherPeople?: return String(localized: "More than one person in the frame: nothing was corrected")
            case .smallEyes?: return String(localized: "Your eyes are too small in the frame to correct")
            case .headTurned?: return String(localized: "Your head is turned too far to correct")
            default: return String(localized: "No face clear enough to correct")
            }
        case .failed:
            return String(localized: "This video couldn’t be read")
        }
    }

    /// What the ✦ Smart tile says under "Eye Contact"; nil while it's off.
    var tileStatus: String? {
        switch self {
        case .off: nil
        case .unavailable, .failed: String(localized: "Unavailable")
        case .preparing(let done, _), .paused(_, let done): min(1, max(0, done)).formatted(.percent.precision(.fractionLength(0)).locale(.interface))
        case .ready: String(localized: "On")
        case .nothingToCorrect: String(localized: "No face")
        }
    }

    /// Whether the work is still going (the panel offers Cancel).
    var isWorking: Bool {
        switch self {
        case .preparing, .paused: true
        default: false
        }
    }

    /// A share as whole percent, 0 to 100 (a part done shows at least 1, and only all of it 100).
    static func percent(_ share: Double) -> Int {
        let value = min(1, max(0, share)) * 100
        guard value > 0 else { return 0 }
        return value >= 100 ? 100 : min(99, max(1, Int(value.rounded(.down))))
    }
}
