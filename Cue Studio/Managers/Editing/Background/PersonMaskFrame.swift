//
//  PersonMaskFrame.swift
//  Cue Studio
//

import CoreImage
import CoreVideo
import Foundation

/// A person mask as bytes, at the size Vision made it (a few hundred pixels a side): 255 where the person is, 0 around them, rows
/// from the top. Small enough to steady on the CPU (`PersonMaskTrack`), and the same bytes in the preview and the export.
nonisolated struct PersonMaskFrame: Equatable, Sendable {
    let width: Int
    let height: Int
    var values: [UInt8]

    init(width: Int, height: Int, values: [UInt8]) {
        self.width = width
        self.height = height
        self.values = values
    }

    /// A copy of Vision's one-component buffer; nil when it isn't one.
    init?(buffer: CVPixelBuffer) {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent8 else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0, let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rows = base.assumingMemoryBound(to: UInt8.self)
        var values = [UInt8](repeating: 0, count: width * height)
        values.withUnsafeMutableBufferPointer { out in
            for row in 0..<height {
                // swiftlint:disable:next force_unwrapping
                (out.baseAddress! + row * width).update(from: rows + row * stride, count: width)
            }
        }
        self.init(width: width, height: height, values: values)
    }

    /// The share of the frame that is the person (above half).
    var coverage: Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0) { $0 + ($1 > 127 ? 1 : 0) }) / Double(values.count)
    }

    /// How much two masks of the same size agree on where the person is: what both call the person over what either does (1 when
    /// both see no one).
    func overlap(with other: PersonMaskFrame) -> Double {
        guard other.width == width, other.height == height else { return 0 }
        var both = 0, either = 0
        for index in values.indices {
            let mine = values[index] > 127, theirs = other.values[index] > 127
            if mine && theirs { both += 1 }
            if mine || theirs { either += 1 }
        }
        return either == 0 ? 1 : Double(both) / Double(either)
    }

    /// The mean change from `other`, 0 to 1 (how much the outline shimmers between two frames).
    func meanChange(from other: PersonMaskFrame) -> Double {
        guard other.width == width, other.height == height, !values.isEmpty else { return 1 }
        var total = 0
        for index in values.indices { total += abs(Int(values[index]) - Int(other.values[index])) }
        return Double(total) / Double(values.count * 255)
    }

    /// The mask stretched over `extent` (a frame with its corner at the origin), for Core Image.
    func image(in extent: CGRect) -> CIImage {
        let mask = CIImage(
            bitmapData: Data(values), bytesPerRow: width, size: CGSize(width: width, height: height), format: .L8, colorSpace: nil
        )
        return mask
            .transformed(by: CGAffineTransform(scaleX: extent.width / CGFloat(width), y: extent.height / CGFloat(height)))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }
}
