//
//  OrbSliderMath.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What an orb control does with a value, apart from drawing it so it can be tested: the mapping
/// between a value and a place on the rail, stepping, the fine control while the finger slides down,
/// the detent at the default value and the one-step moves VoiceOver makes.
nonisolated struct OrbSliderMath: Equatable, Sendable {
    let range: ClosedRange<Double>
    /// Nil for a continuous control.
    let step: Double?
    /// The value a double-tap returns to; a soft tick marks it when the orb passes.
    let defaultValue: Double?

    init(range: ClosedRange<Double>, step: Double? = nil, defaultValue: Double? = nil) {
        self.range = range
        self.step = step.flatMap { $0 > 0 ? $0 : nil }
        self.defaultValue = defaultValue.map { min(range.upperBound, max(range.lowerBound, $0)) }
    }

    var span: Double { range.upperBound - range.lowerBound }

    // MARK: - Mapping

    /// Where `value` sits on the rail, 0...1.
    func fraction(of value: Double) -> Double {
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    /// The value at a place on the rail, snapped when the control is stepped.
    func value(atFraction fraction: Double) -> Double {
        snapped(range.lowerBound + min(1, max(0, fraction)) * span)
    }

    /// The nearest allowed value: on a step when stepped, inside the range always.
    func snapped(_ value: Double) -> Double {
        let clamped = min(range.upperBound, max(range.lowerBound, value))
        guard let step else { return clamped }
        let steps = ((clamped - range.lowerBound) / step).rounded()
        return min(range.upperBound, range.lowerBound + steps * step)
    }

    /// How many steps there are (the stars under a stepped rail), counting both ends.
    var stepCount: Int {
        guard let step else { return 0 }
        return Int(((span) / step).rounded()) + 1
    }

    /// The places of the step stars on the rail, 0...1.
    var stepFractions: [Double] {
        guard let step else { return [] }
        return (0..<stepCount).map { fraction(of: range.lowerBound + Double($0) * step) }
    }

    /// The index of `value` among the steps.
    func stepIndex(of value: Double) -> Int {
        guard let step else { return 0 }
        return Int(((snapped(value) - range.lowerBound) / step).rounded())
    }

    // MARK: - Fine control

    /// How much of the finger's movement counts: all of it, then half and a quarter as the finger slides
    /// down while holding ("FINE · ½", "FINE · ¼"). Only a continuous control has it.
    func precision(forVerticalDrag distance: CGFloat) -> Precision {
        guard step == nil else { return .full }
        if distance > Self.quarterDistance { return .quarter }
        if distance > Self.halfDistance { return .half }
        return .full
    }

    static let halfDistance: CGFloat = 36
    static let quarterDistance: CGFloat = 90

    enum Precision: Double, Sendable {
        case full = 1, half = 0.5, quarter = 0.25

        /// The text beside the value while it is not full.
        var label: String? {
            switch self {
            case .full: nil
            case .half: "FINE · ½"
            case .quarter: "FINE · ¼"
            }
        }
    }

    /// The value after the finger moved `translation` points along a rail of `railLength`, from a drag
    /// that began at `anchorValue`. Re-anchor (start a new drag from the current value) when the
    /// precision changes, so the orb never jumps.
    func value(anchor anchorValue: Double, translation: CGFloat, railLength: CGFloat, precision: Precision = .full) -> Double {
        guard railLength > 0 else { return anchorValue }
        let delta = Double(translation / railLength) * span * precision.rawValue
        return snapped(anchorValue + delta)
    }

    // MARK: - Detent and ends

    /// The orb went across the default value, or landed on it (a soft tick).
    func crossesDetent(from old: Double, to new: Double) -> Bool {
        guard let defaultValue else { return false }
        return (old < defaultValue && new >= defaultValue) || (old > defaultValue && new <= defaultValue)
    }

    /// The orb just reached an end of the rail.
    func reachesEnd(from old: Double, to new: Double) -> Bool {
        (new == range.lowerBound && old != range.lowerBound) || (new == range.upperBound && old != range.upperBound)
    }

    // MARK: - VoiceOver

    /// One accessibility step: one step when stepped, 5% of the range otherwise.
    var accessibilityStep: Double { step ?? span * 0.05 }

    func incremented(_ value: Double) -> Double {
        let next = snapped(value + accessibilityStep)
        // A continuous 5% step must not stick at the end because of rounding.
        return step == nil ? min(range.upperBound, value + accessibilityStep) : next
    }

    func decremented(_ value: Double) -> Double {
        let next = snapped(value - accessibilityStep)
        return step == nil ? max(range.lowerBound, value - accessibilityStep) : next
    }
}
