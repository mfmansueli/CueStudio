//
//  AutoAdjustAnalyzer.swift
//  Cue Studio
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Measures a correction for a clip (`AutoCorrection`) from a few of its frames, with Core Image's
/// own analysis (`CIImage.autoAdjustmentFilters`), on the device and off the main thread.
///
/// One correction for the whole clip, never one per frame: frames are taken evenly across the
/// clip, each is analyzed, and the median of what they ask for is the clip's, so a flash, a
/// shadow crossing the face or a fade never moves the exposure or the color of the clip. Red-eye
/// and crop corrections are never asked for: they make no sense on video.
nonisolated enum AutoAdjustAnalyzer {
    /// Frames taken from a clip.
    static let frameCount = 7
    /// Longest side of the frames analyzed, in pixels: the analysis doesn't need more.
    static let maximumSide: CGFloat = 640
    /// Mean luminance a frame must have to say something about the clip: a black or blown-out
    /// frame (a fade, a flash) is skipped.
    static let usableLuminance = 0.04...0.96

    /// Where to look: evenly across `spans` (seconds of the recording, the stretches the clip
    /// plays), by their length, and never at their very edges, where a cut or a fade is.
    static func sampleTimes(in spans: [TimeSpan], count: Int = frameCount) -> [TimeInterval] {
        let spans = spans.filter { $0.duration > 0 }
        let total = spans.reduce(0) { $0 + $1.duration }
        guard total > 0, count > 0 else { return [] }
        return (0..<count).map { index in
            // The middle of each of `count` equal parts of the clip's length.
            var remaining = total * (Double(index) + 0.5) / Double(count)
            for span in spans {
                if remaining <= span.duration { return span.start + remaining }
                remaining -= span.duration
            }
            return spans[spans.count - 1].end
        }
    }

    /// The clip's correction, or nil when no frame could be read. Throws `CancellationError` when
    /// the task is cancelled; frames that can't be read are skipped.
    @concurrent
    static func correction(forVideoAt url: URL, spans: [TimeSpan]) async throws -> AutoCorrection? {
        let times = sampleTimes(in: spans)
        guard !times.isEmpty else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumSide, height: maximumSide)
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let context = CIContext(options: [.cacheIntermediates: false])
        var all: [AutoCorrection] = []
        var usable: [AutoCorrection] = []
        for time in times {
            try Task.checkCancellation()
            guard let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image else { continue }
            let image = CIImage(cgImage: frame)
            guard let measured = correction(from: image) else { continue }
            all.append(measured)
            if let luminance = meanLuminance(of: image, in: context), usableLuminance.contains(luminance) { usable.append(measured) }
        }
        try Task.checkCancellation()
        // If every frame is dark or bright (a night scene), they are all the clip has to go by.
        return AutoCorrection.median(of: usable.isEmpty ? all : usable)
    }

    /// What Core Image asks for on one frame: its analysis for enhancing the picture, without
    /// red-eye or crop.
    static func correction(from image: CIImage) -> AutoCorrection? {
        let filters = image.autoAdjustmentFilters(options: [.enhance: true, .redEye: false, .crop: false])
        return correction(from: filters)
    }

    /// The numbers of the filters Core Image offered; anything else (red-eye, a crop) is left out.
    static func correction(from filters: [CIFilter]) -> AutoCorrection {
        var result = AutoCorrection()
        for filter in filters {
            switch filter.name {
            case "CIVibrance":
                result.vibrance = number(filter, "inputAmount") ?? 0
            case "CIHighlightShadowAdjust":
                result.highlights = number(filter, "inputHighlightAmount") ?? 1
                result.shadows = number(filter, "inputShadowAmount") ?? 0
            case "CIToneCurve":
                let points = (0..<5).compactMap { index -> AutoCorrection.Point? in
                    (filter.value(forKey: "inputPoint\(index)") as? CIVector).map { AutoCorrection.Point(x: Double($0.x), y: Double($0.y)) }
                }
                if points.count == 5 { result.tone = points }
            case "CIFaceBalance":
                if let strength = number(filter, "inputStrength"), strength > 0,
                   let originI = number(filter, "inputOrigI"), let originQ = number(filter, "inputOrigQ") {
                    result.face = AutoCorrection.FaceBalance(
                        originI: originI, originQ: originQ, strength: strength, warmth: number(filter, "inputWarmth") ?? 0
                    )
                }
            default:
                continue
            }
        }
        return result
    }

    private static func number(_ filter: CIFilter, _ key: String) -> Double? {
        (filter.value(forKey: key) as? NSNumber)?.doubleValue
    }

    /// The frame's mean brightness, 0 to 1.
    private static func meanLuminance(of image: CIImage, in context: CIContext) -> Double? {
        let average = CIFilter.areaAverage()
        average.inputImage = image
        average.extent = image.extent
        guard let output = average.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }
}
