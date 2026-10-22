//
//  WatchDemo.swift
//  Cue Studio Watch
//

#if DEBUG
import Foundation

/// The v31 board's states, to see each one without an iPhone (`-watchDemo <name>`, for captures and previews). Debug only.
enum WatchDemo: String, CaseIterable {
    case checking, noSession, readyVoice, readyFreestyle, requesting, countdown, recording, endArmed, saving, saved
    case rehearsalPaused, rehearsalCrown, rehearsalVoice, textPage, textPaused
    case lost, noResponse, failedStart, failedSave, unavailable

    static let script = "Lançamento de outono"

    /// What the iPhone would have said, and what the wrist did.
    var snapshot: WatchDemoSnapshot {
        let now = Date.now
        func state(_ phase: WatchPhase, script: String? = Self.script, voice: Bool = false, speed: Double = 1.2, playing: Bool = false,
                   elapsed: TimeInterval? = nil) -> WatchPhoneState {
            WatchPhoneState(
                phase: phase, scriptTitle: script, followsVoice: voice, speedMultiple: speed, isPlaying: playing,
                recordingStartedAt: elapsed.map { now.addingTimeInterval(-$0) }
            )
        }
        switch self {
        case .checking: return WatchDemoSnapshot(state: nil)
        case .noSession: return WatchDemoSnapshot(state: .noSession)
        case .readyVoice: return WatchDemoSnapshot(state: state(.ready, voice: true))
        case .readyFreestyle: return WatchDemoSnapshot(state: state(.ready, script: nil))
        case .requesting: return WatchDemoSnapshot(state: state(.ready, voice: true), pending: .record)
        case .countdown: return WatchDemoSnapshot(state: state(.countdown(remaining: 2), voice: true))
        case .recording: return WatchDemoSnapshot(state: state(.recording, voice: true, playing: true, elapsed: 42))
        case .endArmed: return WatchDemoSnapshot(state: state(.recording, voice: true, playing: true, elapsed: 51), armed: true)
        case .saving: return WatchDemoSnapshot(state: state(.saving))
        case .saved: return WatchDemoSnapshot(state: state(.saved(take: 4, seconds: 52)))
        case .rehearsalPaused: return WatchDemoSnapshot(state: state(.rehearsal))
        case .rehearsalCrown: return WatchDemoSnapshot(state: state(.rehearsal, speed: 1.4, playing: true), crown: true)
        case .rehearsalVoice: return WatchDemoSnapshot(state: state(.rehearsal, voice: true, playing: true))
        case .textPage: return WatchDemoSnapshot(state: state(.recording, playing: true, elapsed: 64), textPage: true)
        case .textPaused: return WatchDemoSnapshot(state: state(.recording, voice: true, elapsed: 70), textPage: true)
        case .lost:
            var last = state(.recording, voice: true, playing: true, elapsed: 42)
            last.sentAt = now
            return WatchDemoSnapshot(state: last, reachable: false)
        case .noResponse: return WatchDemoSnapshot(state: state(.ready, voice: true), pending: .record, pendingFor: 6)
        case .failedStart: return WatchDemoSnapshot(state: state(.failedStart))
        case .failedSave: return WatchDemoSnapshot(state: state(.failedSave))
        case .unavailable: return WatchDemoSnapshot(state: state(.unavailable))
        }
    }

    /// The demo asked for at launch (`-watchDemo <name>`), if any.
    static var requested: WatchDemo? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-watchDemo"), arguments.indices.contains(index + 1) else { return nil }
        return WatchDemo(rawValue: arguments[index + 1])
    }
}

/// One demo state: what the iPhone said and what is on the wrist.
struct WatchDemoSnapshot {
    var state: WatchPhoneState?
    var reachable = true
    var pending: WatchAction?
    var pendingFor: TimeInterval = 1
    var armed = false
    var crown = false
    var textPage = false
}
#endif
