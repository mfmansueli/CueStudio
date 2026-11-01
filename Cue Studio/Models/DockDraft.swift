//
//  DockDraft.swift
//  Cue Studio
//

import Foundation

/// The Scripts dock as the creator left it: the idea's words, the inspiration it came from and the card's choices (platform, length, format,
/// brand). Kept on disk as it changes (`IdeaDraftService`), so iOS closing Cue while the creator copies something in another app never loses an
/// idea typed or dictated, nor the choices it was meant to be written with. No expiry: it stays until it becomes a script or is cleared.
nonisolated struct DockDraft: Codable, Equatable, Sendable {
    var text: String
    var brief: IdeaBrief?
    var platform: Platform?
    var length: ScriptLength
    /// `FormatChoice.id`.
    var format: String
    var brand: BrandBrief?

    /// Nothing typed and every choice at its default: nothing to keep.
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && brief == nil && platform == nil && length == .auto
            && format == FormatChoice.auto.id && brand == nil
    }
}
