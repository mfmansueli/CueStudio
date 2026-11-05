//
//  FilterFanDismissal.swift
//  Cue Studio
//

import SwiftUI

/// Folds an open `FilterFan` when the list around it scrolls or a finger lands outside the row. The touch still does what it does (a script
/// opens and the row folds with it): folding never spends a tap of its own. A UIKit tap that never holds or cancels the touch, since a
/// SwiftUI gesture on a `List` took the rows' taps.
struct FilterFanDismissal: ViewModifier {
    @Binding var state: FilterFanState

    func body(content: Content) -> some View {
        content
            .gesture(FilterFanOutsideTap(isEnabled: state.isOpen) { location in
                if !state.frame.contains(location) { state.isOpen = false }
            })
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { old, new in
                if state.isOpen, abs(new - old) > 1 { state.isOpen = false }
            })
    }
}

extension View {
    /// On the scroll view that holds a `FilterFan` (`FilterFanDismissal`).
    func foldsFilterFan(_ state: Binding<FilterFanState>) -> some View {
        modifier(FilterFanDismissal(state: state))
    }
}
