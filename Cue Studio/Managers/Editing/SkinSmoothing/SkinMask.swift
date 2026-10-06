//
//  SkinMask.swift
//  Cue Studio
//

import CoreImage

/// Where the skin of one face is, drawn small (`SkinSmoothingCalibration.maskWidth` pixels wide) over the part of the frame the face covers: `skin` is a
/// weight from 0 to 255 (soft at its edges, 0 on the eyes, brows and lips, on the hair and off the face); `core` is the part of it that is surely
/// skin (the forehead and the cheeks, away from the features and the beard), where the face's skin tone is measured. Both are rows of pixels from the
/// top of the region, like an image in memory.
nonisolated struct SkinMask: Sendable {
    /// The part of the frame this covers, in the frame's pixels (whole numbers).
    let region: CGRect
    let width: Int
    let height: Int
    let skin: [UInt8]
    let core: [UInt8]

    /// About how many pixels are surely skin (every fourth one is counted, which is plenty to tell a face from nothing).
    var coreCount: Int {
        core.withUnsafeBufferPointer { pixels in
            var count = 0
            for index in stride(from: 0, to: pixels.count, by: 4) where pixels[index] >= 128 { count += 4 }
            return count
        }
    }

    /// The weights as a grey image laid over `region`, to blend with: the values are the weights themselves (no color management).
    func image() -> CIImage? {
        guard width > 0, height > 0, let provider = CGDataProvider(data: Data(skin) as CFData) else { return nil }
        guard let grey = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider, decode: nil, shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        return CIImage(cgImage: grey, options: [.colorSpace: NSNull()])
            .transformed(by: CGAffineTransform(scaleX: region.width / CGFloat(width), y: region.height / CGFloat(height)))
            .transformed(by: CGAffineTransform(translationX: region.minX, y: region.minY))
            .samplingLinear()
    }
}
