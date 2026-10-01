//
//  PanelValueFormat.swift
//  Cue Studio
//

import Foundation

/// How a slider shows its value.
enum PanelValueFormat {
    /// "150%" (the value is already in percent).
    case percent
    /// "+12", "0", "−8".
    case signed
    /// "0".."100".
    case plain
    /// "1.5s".
    case seconds
    /// "1.25×".
    case speed
    /// "26 pt".
    case points

    func text(_ value: Double) -> String {
        switch self {
        case .percent: value.formatted(.percent.precision(.fractionLength(0)).scale(1).locale(.interface))
        case .signed: value > 0.5 ? "+\(Int(value.rounded()))" : "\(Int(value.rounded()))"
        case .plain: "\(Int(value.rounded()))"
        case .seconds: DurationText.tenths(value)
        case .speed: value.formatted(.number.precision(.fractionLength(0...2)).locale(.interface)) + "×"
        case .points: String(localized: "\(Int(value.rounded())) pt")
        }
    }
}
