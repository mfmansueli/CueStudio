//
//  MotionEasing.swift
//  Cue Studio
//

import SwiftUI

/// The timing function of one stretch of a board's animation, as the baked JSON writes it: a `cubic-bezier` (as four numbers, or as the
/// CSS text), the CSS keywords, or `steps(n, end)`.
nonisolated enum MotionEasing: Decodable, Sendable {
    case linear
    case curve(UnitCurve)
    case steps(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let numbers = try? container.decode([Double].self), numbers.count == 4 {
            self = .curve(.css(numbers[0], numbers[1], numbers[2], numbers[3]))
        } else if let text = try? container.decode(String.self) {
            self = Self.parse(text)
        } else {
            self = .linear
        }
    }

    /// `linear`, `ease`, `ease-in`, `ease-out`, `ease-in-out`, `cubic-bezier(a, b, c, d)` and `steps(n, end)`.
    static func parse(_ text: String) -> MotionEasing {
        let value = text.trimmingCharacters(in: .whitespaces)
        switch value {
        case "ease": return .curve(.css(0.25, 0.1, 0.25, 1))
        case "ease-in": return .curve(.css(0.42, 0, 1, 1))
        case "ease-out": return .curve(.css(0, 0, 0.58, 1))
        case "ease-in-out": return .curve(.css(0.42, 0, 0.58, 1))
        default: break
        }
        if value.hasPrefix("cubic-bezier("), let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")") {
            let numbers = value[value.index(after: open)..<close].split(separator: ",").compactMap {
                Double($0.trimmingCharacters(in: .whitespaces))
            }
            if numbers.count == 4 { return .curve(.css(numbers[0], numbers[1], numbers[2], numbers[3])) }
        }
        if value.hasPrefix("steps("), let open = value.firstIndex(of: "(") {
            let count = value[value.index(after: open)...].prefix { $0.isNumber }
            if let steps = Int(count) { return .steps(steps) }
        }
        return .linear
    }

    /// The eased progress for `progress` (0...1) of the stretch.
    func value(at progress: Double) -> Double {
        switch self {
        case .linear: progress
        case .curve(let curve): curve.value(at: progress)
        case .steps(let count): count > 0 ? (progress * Double(count)).rounded(.down) / Double(count) : progress
        }
    }
}
