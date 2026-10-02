//
//  FrameLook+Auto.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Draws an `AutoCorrection` with the Core Image filters its numbers came from, in the order
/// Core Image's analysis offers them: face balance, vibrance, tone curve, highlights and shadows.
/// The numbers are fixed, so every frame of a clip gets exactly the same correction.
nonisolated enum AutoCorrectionRenderer {
    static func apply(_ correction: AutoCorrection, to image: CIImage) -> CIImage {
        var output = image
        if let face = correction.face, face.strength > 0.001,
           let filter = CIFilter(name: "CIFaceBalance", parameters: [
               kCIInputImageKey: output, "inputOrigI": face.originI, "inputOrigQ": face.originQ,
               "inputStrength": face.strength, "inputWarmth": face.warmth,
           ]) {
            output = filter.outputImage ?? output
        }
        if abs(correction.vibrance) > AutoCorrection.tolerance {
            let filter = CIFilter.vibrance()
            filter.inputImage = output
            filter.amount = Float(correction.vibrance)
            output = filter.outputImage ?? output
        }
        if correction.tone.count == 5, correction.tone.contains(where: { abs($0.y - $0.x) > AutoCorrection.tolerance / 2 }) {
            output = FrameLook.curve(correction.tone.map { CGPoint(x: $0.x, y: $0.y) }, on: output)
        }
        if correction.highlights < 1 - AutoCorrection.tolerance / 2 || abs(correction.shadows) > AutoCorrection.tolerance / 2 {
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = output
            filter.highlightAmount = Float(correction.highlights)
            filter.shadowAmount = Float(correction.shadows)
            output = filter.outputImage ?? output
        }
        return output
    }
}
