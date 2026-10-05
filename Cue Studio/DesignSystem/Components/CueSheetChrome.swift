//
//  CueSheetChrome.swift
//  Cue Studio
//

import SwiftUI

/// The system's chrome for a Cue sheet (07-Liquid-Glass §1): a navigation stack whose only item is the native close button, a
/// glass circle with an xmark at the leading edge. The title and subtitle stay in the content (`SheetHeader`); the sheet's
/// background is the system's glass.
struct CueSheetChrome: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                            .accessibilityIdentifier("sheet.closeButton")
                    }
                }
        }
    }
}

extension View {
    /// Wraps a sheet's content in the system chrome: the native close button and glass background.
    func cueSheetChrome() -> some View {
        modifier(CueSheetChrome())
    }
}
