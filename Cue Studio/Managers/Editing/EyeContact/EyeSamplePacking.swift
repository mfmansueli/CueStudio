//
//  EyeSamplePacking.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// `EyeSample`s as a block of little-endian numbers, one fixed-size record per frame: the time (a Float64), a flags byte (a face, a
/// crowded frame), then the confidence, the face's box, the eyes' sharpness and each eye's 16 outline points, iris centre and iris
/// radius as Float32. Pure.
nonisolated enum EyeSamplePacking {
    enum PackingError: Error { case damaged }

    /// Float32s per eye: outline (16 × 2), iris centre (2), iris radius.
    private static let eyeFloats = EyeShape.pointCount * 2 + 3
    /// Float32s after the time and the flags: confidence, box (4), sharpness, two eyes.
    private static let floats = 1 + 4 + 1 + 2 * eyeFloats
    static let recordSize = 8 + 1 + floats * 4

    static func pack(_ samples: [EyeSample]) -> Data {
        var data = Data(capacity: samples.count * recordSize)
        for sample in samples {
            append(sample.time.bitPattern, to: &data)
            var flags: UInt8 = 0
            var values = [Float](repeating: 0, count: floats)
            if let face = sample.face, face.eyes.count == 2, face.eyes.allSatisfy(\.isComplete) {
                flags |= 1
                if face.crowded { flags |= 2 }
                values[0] = Float(face.confidence)
                values[1] = Float(face.box.minX)
                values[2] = Float(face.box.minY)
                values[3] = Float(face.box.width)
                values[4] = Float(face.box.height)
                values[5] = Float(face.sharpness)
                var index = 6
                for eye in face.eyes {
                    for point in eye.contour + [eye.iris] {
                        values[index] = Float(point.x)
                        values[index + 1] = Float(point.y)
                        index += 2
                    }
                    values[index] = Float(eye.irisRadius)
                    index += 1
                }
            }
            data.append(flags)
            for value in values { append(value.bitPattern, to: &data) }
        }
        return data
    }

    static func unpack(_ data: Data) throws -> [EyeSample] {
        guard data.count % recordSize == 0 else { throw PackingError.damaged }
        let bytes = [UInt8](data)
        var samples: [EyeSample] = []
        samples.reserveCapacity(bytes.count / recordSize)
        var offset = 0
        while offset < bytes.count {
            let time = Double(bitPattern: read(UInt64.self, bytes, at: offset))
            let flags = bytes[offset + 8]
            var values = [Double](repeating: 0, count: floats)
            for index in 0..<floats {
                values[index] = Double(Float(bitPattern: read(UInt32.self, bytes, at: offset + 9 + index * 4)))
            }
            offset += recordSize
            guard time.isFinite else { throw PackingError.damaged }
            guard flags & 1 != 0 else {
                samples.append(EyeSample(time: time, face: nil))
                continue
            }
            var eyes: [EyeShape] = []
            var index = 6
            for _ in 0..<2 {
                var points: [SIMD2<Double>] = []
                for _ in 0...EyeShape.pointCount {
                    points.append(SIMD2(values[index], values[index + 1]))
                    index += 2
                }
                eyes.append(EyeShape(contour: Array(points.prefix(EyeShape.pointCount)), iris: points[EyeShape.pointCount], irisRadius: values[index]))
                index += 1
            }
            let box = CGRect(x: values[1], y: values[2], width: values[3], height: values[4])
            samples.append(EyeSample(
                time: time,
                face: EyeSample.Face(box: box, confidence: values[0], crowded: flags & 2 != 0, eyes: eyes, sharpness: values[5])
            ))
        }
        return samples
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func read<T: FixedWidthInteger>(_: T.Type, _ bytes: [UInt8], at offset: Int) -> T {
        var value: T = 0
        for index in 0..<MemoryLayout<T>.size {
            value |= T(bytes[offset + index]) << (8 * index)
        }
        return value
    }
}
