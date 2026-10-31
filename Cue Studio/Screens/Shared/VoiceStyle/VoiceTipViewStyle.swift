//
//  VoiceTipViewStyle.swift
//  Cue Studio
//

import SwiftUI
import TipKit

/// The look of the My Cue Voice tip: Cue's one tip form (`TipCard`), compact, with the ✦ disc (the subject is AI), the question as the title
/// and one line under it, and the system's xmark at the end (44 pt to touch).
struct VoiceTipViewStyle: TipViewStyle {
    /// A tap on the tip (not on its ✕) opens the question.
    let onOpen: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        TipCard(
            sign: .ai, title: configuration.title ?? Text(verbatim: ""), message: configuration.message, onOpen: onOpen,
            identifierPrefix: "voice.tip", onClose: { configuration.tip.invalidate(reason: .tipClosed) }
        )
    }
}
