//
//  ExportOutputChoice.swift
//  Cue Studio
//

import Foundation

/// What one export burns into the file besides the edit (D11): whether its captions go in, and in which language. It starts from the
/// editor (`editorDefault(of:)`: the captions the edit shows, in the language it shows them, a translation included), and an output option
/// never changes the saved edit: a choice that differs from the editor applies to the exports of that version only, and says so
/// (`difference(from:)`).
nonisolated struct ExportOutputChoice: Equatable, Sendable {
    var burnsInCaptions: Bool
    var captionDisplay: CaptionDisplay

    /// The editor's own: the edit's captions shown or hidden, in its caption language. A never-edited take has none.
    static func editorDefault(of edit: TakeEdit?) -> ExportOutputChoice {
        ExportOutputChoice(burnsInCaptions: edit?.showsCaptions ?? false, captionDisplay: edit?.captionDisplay ?? .original)
    }

    /// How this choice differs from what the editor shows, for the line that says so; nil when it is the editor's.
    func difference(from editor: ExportOutputChoice) -> Difference? {
        if burnsInCaptions != editor.burnsInCaptions { return burnsInCaptions ? .addsCaptions : .removesCaptions }
        if burnsInCaptions, captionDisplay != editor.captionDisplay { return .otherLanguage }
        return nil
    }

    /// What only the export changes.
    enum Difference: Equatable, Sendable {
        /// Captions in the video although the editor hides them.
        case addsCaptions
        /// No captions in the video although the editor shows them.
        case removesCaptions
        /// The captions in another language (or both) than the editor's.
        case otherLanguage

        var text: String {
            switch self {
            case .addsCaptions: String(localized: "Captions in this export only · your edit stays as it is")
            case .removesCaptions: String(localized: "No captions in this export · your edit keeps them")
            case .otherLanguage: String(localized: "Caption language for this export only · your edit keeps its own")
            }
        }
    }
}
