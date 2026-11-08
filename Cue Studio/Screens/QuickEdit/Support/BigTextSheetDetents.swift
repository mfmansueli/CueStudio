//
//  BigTextSheetDetents.swift
//  Cue Studio
//

import SwiftUI

/// A sheet's heights, opening full height at the accessibility text sizes: at those sizes a half sheet on an SE showed a line of
/// a list or cut its buttons (captures 08/11/2026). The sheet can still be pulled down to `regular`.
struct BigTextSheetDetents: ViewModifier {
    let regular: PresentationDetent

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: PresentationDetent?

    func body(content: Content) -> some View {
        content
            .presentationDetents(
                [regular, .large],
                selection: Binding(get: { selection ?? start }, set: { selection = $0 })
            )
    }

    private var start: PresentationDetent { dynamicTypeSize.isAccessibilitySize ? .large : regular }
}

extension View {
    /// `regular` high, or full height at the accessibility text sizes (`BigTextSheetDetents`).
    func bigTextSheetDetents(_ regular: PresentationDetent) -> some View {
        modifier(BigTextSheetDetents(regular: regular))
    }
}
