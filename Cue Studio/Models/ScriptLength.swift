//
//  ScriptLength.swift
//  Cue Studio
//

import Foundation

/// "Length" when generating from a prompt. Auto follows the platform's ideal range.
nonisolated enum ScriptLength: String, CaseIterable, Identifiable, Sendable {
    case auto, seconds30, minute1, minutes2, minutes3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .seconds30: String(localized: "30s")
        case .minute1: String(localized: "1 min")
        case .minutes2: String(localized: "2 min")
        case .minutes3: String(localized: "3 min")
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .auto: nil
        case .seconds30: 30
        case .minute1: 60
        case .minutes2: 120
        case .minutes3: 180
        }
    }

    /// Seconds the script should run: a ±10% window around a fixed length (at 150 words/min,
    /// 2 min ≈ 300 words), or the platform's ideal range.
    func targetRange(ideal: ClosedRange<TimeInterval>) -> ClosedRange<TimeInterval> {
        guard let seconds else { return ideal }
        return (seconds - seconds / 10)...(seconds + seconds / 10)
    }

    /// Reads "2 minutes on…" or "a 30-second video about…" in a prompt.
    static func detected(in prompt: String) -> ScriptLength? {
        let text = prompt.lowercased()
        if text.contains(/\b(30|thirty)[\s-]*(s|sec|second)/) { return .seconds30 }
        if text.contains(/\b(1|one|a)[\s-]*(min|minute)\b/) { return .minute1 }
        if text.contains(/\b(2|two)[\s-]*(min|minute)/) { return .minutes2 }
        if text.contains(/\b(3|three)[\s-]*(min|minute)/) { return .minutes3 }
        return nil
    }
}
