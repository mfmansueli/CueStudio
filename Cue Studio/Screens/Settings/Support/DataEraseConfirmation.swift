//
//  DataEraseConfirmation.swift
//  Cue Studio
//

import SwiftUI

/// The confirmation of "Delete my Cue data": the board's action sheet at the bottom, with Cancel (`CueActionSheet`). Where Ultra AI is offered,
/// a line under the question says what deleting can't reach (owner, 09/11/2026): what already went to Anthropic, and the counts on Cue's server.
private struct DataEraseConfirmation: ViewModifier {
    @Environment(DataEraserService.self) private var eraser
    @Environment(ToastService.self) private var toast
    @Environment(UltraScriptService.self) private var ultra

    func body(content: Content) -> some View {
        @Bindable var eraser = eraser
        content.cueActionSheet(
            isPresented: $eraser.isConfirming,
            message: "Deletes your scripts, takes, edits and My Cue Voice from this iPhone. This can't be undone.",
            note: ultra.isAvailable ? "Already sent can’t be called back: Anthropic keeps Ultra AI requests up to 30 days to detect abuse, never for training. Cue’s server keeps only counts, under a random ID." : nil,
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
