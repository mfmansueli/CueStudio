//
//  TakeReviewViewModel+ExportOptions.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Export options (D11): one state for this video, read by Save, Share and Done's answers alike, and shown by one component
/// (`ShareExportOptions`) wherever the creator reaches it: Ready to travel's "Options · 1080p", the review's quiet line, the editor's Done.
/// The captions start from the editor (a translation included); a choice that differs from it applies to the export only and says so; the
/// saved edit never changes.
extension TakeReviewViewModel {
    /// What the file of `take` is made with: its frame, the edit, the captions and the short side picked.
    func exportOptions(for take: Take, edit: TakeEdit?, burnsInCaptions: Bool) -> ExportOptions {
        ExportOptions(aspect: take.outputAspect, edit: edit, burnsInCaptions: burnsInCaptions, shortSide: outputShortSide(for: take))
    }

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

    /// "1080p · captions on" (or "606×1080 · captions on" when the format's crop makes the file smaller than its quality): what exporting
    /// `edit` is made with, for the quiet lines that open Export options.
    func outputSummary(for edit: TakeEdit?) -> String {
        let captions = output(for: edit).burnsInCaptions ? String(localized: "captions on") : String(localized: "no captions")
        return "\(outputSizeLabel(for: edit)) · \(captions)"
    }

    // MARK: - The file's real size

    /// The pixels exporting `edit` makes when they are fewer than its quality says: a landscape 1080p recording at 9:16 is 606×1080, never
    /// enlarged to 1080×1920 (`ExportFrameSize`). Nil when the quality's name is true, or while an imported video's frame isn't read yet.
    func reducedOutputSize(for edit: TakeEdit?) -> CGSize? {
        guard let take, let upright = recordingFrame(of: take) else { return nil }
        let shortSide = outputShortSide(for: take)
        return ExportFrameSize.reducedByCrop(
            uprightSize: upright, aspect: edit?.aspect ?? take.aspect, shortSide: shortSide,
            nominalShortSide: shortSide ?? CGFloat(take.resolution.landscapeHeight)
        )
    }

    /// "606×1080" when the file is smaller than its quality, else "1080p" (`effectiveQualityLabel`).
    func outputSizeLabel(for edit: TakeEdit?) -> String {
        reducedOutputSize(for: edit).map(ExportFrameSize.label) ?? effectiveQualityLabel
    }

    /// "This format exports at 606×1080 · never enlarged": under Quality when the file is smaller than its quality.
    func outputSizeNote(for edit: TakeEdit?) -> String? {
        reducedOutputSize(for: edit).map(ExportFrameSize.note)
    }

    /// Reads the recording's upright frame from its file, once.
    func loadRecordingFrame() async {
        guard recordingUprightSize == nil, let url = videoURL, let shape = await EditFraming.shape(of: url) else { return }
        recordingUprightSize = shape.uprightSize
    }

    /// The frame the export crops: the file's, once read; before that a Cue recording's (always the whole portrait sensor), and nothing
    /// for an imported video, whose shape only its file knows.
    private func recordingFrame(of take: Take) -> CGSize? {
        if let recordingUprightSize { return recordingUprightSize }
        guard !take.isImported else { return nil }
        return CGSize(width: take.resolution.landscapeHeight, height: take.resolution.landscapeWidth)
    }
}
