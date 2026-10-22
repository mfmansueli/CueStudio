//
//  WatchSpeed.swift
//  Cue Studio Watch
//

import Foundation

/// The speed as the iPhone writes it: times the natural pace, "1×", "1.2×", with the interface's decimal separator.
enum WatchSpeed {
    static let range: ClosedRange<Double> = 0.2...2

    static func label(_ multiple: Double) -> String {
        multiple.formatted(.number.precision(.fractionLength(0...1))) + "×"
    }
}
