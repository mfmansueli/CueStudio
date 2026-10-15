//
//  SymbolSwap.swift
//  Cue Studio
//

import SwiftUI

/// An SF Symbol that changes with a state (play ↔ pause, eye ↔ eye with a slash, star ↔ filled star) redraws as the system does it (`replace`:
/// the old one shrinks and fades while the new one grows in), quick and with no bounce, instead of jumping. Reduce Motion: the system's own
/// replace is already a cross-fade.
private struct SymbolSwap<Value: Equatable>: ViewModifier {
    let value: Value

    func body(content: Content) -> some View {
        content
            .contentTransition(.symbolEffect(.replace))
            .animation(CueMotion.symbolSwap, value: value)
    }
}

extension View {
    /// The symbol swaps with `value` (`SymbolSwap`).
    func symbolSwap<Value: Equatable>(value: Value) -> some View {
        modifier(SymbolSwap(value: value))
    }
}
