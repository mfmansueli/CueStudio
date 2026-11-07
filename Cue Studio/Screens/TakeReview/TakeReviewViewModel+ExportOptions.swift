//
//  TakeReviewViewModel+ExportOptions.swift
//  Cue Studio
//

import Foundation

/// Export options (D11): one state for this video, read by Save, Share and Done's answers alike, and shown by one component
/// (`ShareExportOptions`) wherever the creator reaches it: Ready to travel's "Options · 1080p", the review's quiet line, the editor's Done.
/// The captions start from the editor (a translation included); a choice that differs from it applies to the export only and says so; the
/// saved edit never changes.
extension TakeReviewViewModel {
    /// What exporting `edit` burns in: what Export options picked while the editor showed these same captions, else the editor's.
    func output(for edit: TakeEdit?) -> ExportOutputChoice {
        let editor = ExportOutputChoice.editorDefault(of: edit)
        guard let pickedOutput, pickedOutput.editor == editor else { return editor }
        return pickedOutput.choice
    }

    /// A pick in Export options, about `edit` (the saved one, or the one Done is about to save): back to the editor's own forgets it.
    func setOutput(_ choice: ExportOutputChoice, for edit: TakeEdit?) {
        let editor = ExportOutputChoice.editorDefault(of: edit)
        pickedOutput = choice == editor ? nil : (editor, choice)
    }

    /// What only the export of `edit` changes, for the line under the captions; nil when it is the editor's.
    func outputDifference(for edit: TakeEdit?) -> ExportOutputChoice.Difference? {
        output(for: edit).difference(from: .editorDefault(of: edit))
    }

    /// "1080p", "4K" or "720p": the quality the file is made in, with Pro's rule applied (a 4K recording without Pro says 1080p).
    var effectiveQualityLabel: String {
        take.map(outputResolutionLabel(for:)) ?? exportQuality.label
    }

    /// "1080p · captions on": what exporting `edit` is made with, for the quiet lines that open Export options.
    func outputSummary(for edit: TakeEdit?) -> String {
        let captions = output(for: edit).burnsInCaptions ? String(localized: "captions on") : String(localized: "no captions")
        return "\(effectiveQualityLabel) · \(captions)"
    }
}
