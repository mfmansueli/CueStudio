//
//  UnitCurve+CSS.swift
//  Cue Studio
//

import SwiftUI

nonisolated extension UnitCurve {
    /// A CSS `cubic-bezier(x1, y1, x2, y2)`, as the board's motion values are written.
    static func css(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> UnitCurve {
        .bezier(startControlPoint: UnitPoint(x: x1, y: y1), endControlPoint: UnitPoint(x: x2, y: y2))
    }

    /// CSS `ease-out`.
    static let cssEaseOut = UnitCurve.css(0, 0, 0.58, 1)
}
