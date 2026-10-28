//
//  UIImage+ClipShape.swift
//  Cue Studio
//

import UIKit

extension UIImage {
    /// This frame (read upright) as a clip turns, mirrors and crops it (`FramePipeline.oriented`), for the copies of it shown on
    /// screen (Reorder, Filters, Cover, the split screen's drag); itself when the clip keeps it as filmed or it can't be drawn.
    nonisolated func shaped(by orientation: ClipOrientation) -> UIImage {
        guard !orientation.isIdentity, let picture = cgImage, let shaped = FramePipeline.oriented(picture, by: orientation) else { return self }
        return UIImage(cgImage: shaped, scale: scale, orientation: .up)
    }
}
