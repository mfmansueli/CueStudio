//
//  CueSheetChrome.swift
//  Cue Studio
//

import SwiftUI

/// The system's chrome for a Cue sheet (07-Liquid-Glass §1): a navigation stack whose only item is the native close button, a
/// glass circle with an xmark at the leading edge. The title and subtitle stay in the content (`SheetHeader`). The sheet is the app's night
/// (`Palette.sheetNight`, the corner of `Metrics.sheetRadius`): without it a sheet is the system's flat grey, which is not Cue's (a sheet can still
/// set its own background after this one, as the editor's panels do).
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
        .cueSheetSurface()
    }
}

extension View {
    /// Wraps a sheet's content in the system chrome: the native close button and glass background.
    func cueSheetChrome() -> some View {
        modifier(CueSheetChrome())
    }

    /// The app's night and corner for a sheet that has its own navigation (a stack with a title or steps) and so doesn't use `cueSheetChrome()`.
    func cueSheetSurface() -> some View {
        presentationBackground(Palette.sheetNight).presentationCornerRadius(Metrics.sheetRadius)
    }
}
