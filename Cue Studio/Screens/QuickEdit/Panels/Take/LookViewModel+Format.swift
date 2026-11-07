//
//  LookViewModel+Format.swift
//  Cue Studio
//

import Foundation

/// Aspect ratio's own (F16): the file's real size when the format's crop leaves fewer pixels than the quality, and Reset back to the
/// video as it was recorded. Follow face is never turned on here: only the creator's switch does (owner, 07/11/2026).
extension LookViewModel {
    /// "This format exports at 606×1080 · never enlarged": a landscape 1080p recording at 9:16, said where the format is picked.
    var exportSizeNote: String? {
        reducedExportSize(edit).map(ExportFrameSize.note)
    }

    /// The format as the video starts: the recording's ratio, Fill, centered, Follow face off.
    var formatIsChanged: Bool {
        edit.aspect != session.take.aspect || edit.cropOffset != 0 || edit.cropFit != .fill || edit.faceFollow != nil
    }

    /// Reset in the header: the recording's ratio, Fill, centered, Follow face off, in one undo step.
    func resetFormat() {
        let recorded = session.take.aspect
        changeEdit { edit in
            edit.aspect = recorded
            edit.cropOffset = 0
            edit.cropFit = .fill
            edit.faceFollow = nil
        }
    }
}
