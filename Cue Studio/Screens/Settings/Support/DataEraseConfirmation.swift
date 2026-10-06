//
//  DataEraseConfirmation.swift
//  Cue Studio
//

import SwiftUI

/// The confirmation of "Delete my Cue data": the board's action sheet at the bottom, with Cancel (`CueActionSheet`).
private struct DataEraseConfirmation: ViewModifier {
    @Environment(DataEraserService.self) private var eraser
    @Environment(ToastService.self) private var toast

    func body(content: Content) -> some View {
        @Bindable var eraser = eraser
        content.cueActionSheet(
            isPresented: $eraser.isConfirming,
            message: "Deletes your scripts, takes, edits and My Cue Voice from this iPhone. This can't be undone.",
            actionTitle: "Delete my Cue data", actionIdentifier: "privacy.confirmDelete"
        ) {
            eraser.eraseEverything()
            toast.show(String(localized: "Your Cue data is deleted"))
        }
    }
}

extension View {
    func confirmsDataErase() -> some View {
        modifier(DataEraseConfirmation())
    }
}
