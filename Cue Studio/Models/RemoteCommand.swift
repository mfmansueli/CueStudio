//
//  RemoteCommand.swift
//  Cue Studio
//

import Foundation

/// What a remote can ask the teleprompter to do. Every controller speaks these: another iPhone or
/// iPad today; a keyboard, foot pedal or presentation remote later only needs to turn its keys into
/// commands.
nonisolated enum RemoteCommand: String, Codable, CaseIterable, Sendable {
    case togglePlay, play, pause, faster, slower, forward, backward, restart

    /// One tap of − or +, like a step of the speed slider.
    static let speedStep = 0.1
    /// Lines per tap of ‹‹ or ››, like Studio mode's buttons.
    static let jumpLines = 3

    var label: String {
        switch self {
        case .togglePlay: String(localized: "Play or pause")
        case .play: String(localized: "Play")
        case .pause: String(localized: "Pause")
        case .faster: String(localized: "Faster")
        case .slower: String(localized: "Slower")
        case .forward: String(localized: "Forward three lines")
        case .backward: String(localized: "Back three lines")
        case .restart: String(localized: "Back to the top")
        }
    }
}
